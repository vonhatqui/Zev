import Foundation
import UIKit

// MARK: - GamePatchService
// Cơ chế nạp & gỡ bản vá (Loader -> Injector -> Uninjector)
// Hỗ trợ gói .3105 (giải mã AES-GCM + password), file .bytes/Assembly, và file đính kèm localconfig.json vào Documents/

enum PatchError: LocalizedError {
    case gameContainerNotFound(String)
    case fileDownloadFailed(String)
    case unsupportedFormat(String)
    case permissionDenied(String)
    case applyFailed(String)
    case uninjectFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .gameContainerNotFound(let bundleId):
            return "Không tìm thấy thư mục lưu trữ của game (\(bundleId)). Vui lòng đảm bảo game đã được mở ít nhất một lần trên thiết bị."
        case .fileDownloadFailed(let reason):
            return "Tải file từ máy chủ thất bại: \(reason)"
        case .unsupportedFormat(let ext):
            return "Định dạng file không được hỗ trợ: .\(ext)"
        case .permissionDenied(let path):
            return "Không đủ quyền truy cập filesystem tại: \(path). Yêu cầu ứng dụng có quyền MobileHouseArrest hoặc cài đặt qua TrollStore / chứng chỉ hợp lệ."
        case .applyFailed(let msg):
            return "Lỗi khi áp dụng bản vá: \(msg)"
        case .uninjectFailed(let msg):
            return "Lỗi khi gỡ bản vá: \(msg)"
        }
    }
}

// MARK: - Injection Record Manifest
// Lưu vết các file đã nạp để Uninjector có thể gỡ sạch không để lại dấu vết
struct InjectionRecord: Codable {
    let bundleId: String
    let timestamp: TimeInterval
    let patchTitle: String
    let injectedPaths: [String]
    let backupMap: [String: String] // targetPath -> backupPath
}

final class GamePatchService {
    
    static let shared = GamePatchService()
    private init() {}
    
    private let fm = FileManager.default
    private let manifestPrefix = "zev.injected_manifest."
    
    // MARK: - Status Tracking
    
    /// Kiểm tra game này hiện tại đã được nạp bản vá hay chưa
    func isInjected(bundleId: String) -> Bool {
        guard let record = getInjectionRecord(bundleId: bundleId) else { return false }
        for path in record.injectedPaths {
            if fm.fileExists(atPath: path) {
                return true
            }
        }
        return false
    }
    
    /// Lấy bản ghi nạp hiện tại của game
    func getInjectionRecord(bundleId: String) -> InjectionRecord? {
        guard let data = UserDefaults.standard.data(forKey: manifestPrefix + bundleId) else {
            return nil
        }
        return try? JSONDecoder().decode(InjectionRecord.self, from: data)
    }
    
    private func saveInjectionRecord(_ record: InjectionRecord) {
        if let data = try? JSONEncoder().encode(record) {
            UserDefaults.standard.set(data, forKey: manifestPrefix + record.bundleId)
            UserDefaults.standard.synchronize()
        }
    }
    
    private func clearInjectionRecord(bundleId: String) {
        UserDefaults.standard.removeObject(forKey: manifestPrefix + bundleId)
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Apply Active Patch (1-File + Optional Config)
    
    /// Nạp bản vá duy nhất (Main file + localconfig.json) vào Documents của game
    func applyActivePatch(
        game: Game,
        patch: ActiveGamePatch,
        progressHandler: @escaping (Double, String) -> Void
    ) async throws {
        let targetBundleId = game.bundleId
        
        guard let liveContainer = GameDetectionService.shared.resolveAppContainer(bundleId: targetBundleId) else {
            throw PatchError.gameContainerNotFound(targetBundleId)
        }
        
        progressHandler(0.15, "Đang kết nối máy chủ...")
        
        // 1. Tải file chính (Main patch file)
        let tokenResponse = try await APIService.shared.requestDownloadToken(fileId: patch.fileId)
        guard let downloadURL = URL(string: tokenResponse.downloadUrl) else {
            throw PatchError.fileDownloadFailed("URL tải file chính không hợp lệ.")
        }
        
        progressHandler(0.35, "Đang tải file bản vá (\(patch.fileName))...")
        let (tempMainURL, _) = try await URLSession.shared.download(from: downloadURL)
        let mainData = try Data(contentsOf: tempMainURL)
        
        var injectedPaths: [String] = []
        var backupMap: [String: String] = [:]
        let timestamp = Int(Date().timeIntervalSince1970)
        let backupBaseDir = URL(fileURLWithPath: liveContainer).appendingPathComponent("Documents/Zev_Backups/\(timestamp)")
        
        // 2. NẠP FILE CHÍNH
        if PatchPackageCodec.is3105Package(data: mainData) {
            progressHandler(0.55, "Đang giải mã gói .3105...")
            let decoded = try PatchPackageCodec.decode(mainData, password: patch.filePassword)
            
            progressHandler(0.70, "Đang nạp các file từ gói .3105 vào Documents...")
            for rule in decoded.project.rules {
                let ruleBundle = rule.bundleID.isEmpty ? targetBundleId : rule.bundleID
                guard let containerRoot = GameDetectionService.shared.resolveAppContainer(bundleId: ruleBundle) else {
                    continue
                }
                
                let destURL = URL(fileURLWithPath: containerRoot).appendingPathComponent(rule.relativePath)
                try fm.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                
                // Sao lưu file gốc trước khi ghi đè
                if fm.fileExists(atPath: destURL.path) {
                    try? fm.createDirectory(at: backupBaseDir, withIntermediateDirectories: true)
                    let backupDest = backupBaseDir.appendingPathComponent(destURL.lastPathComponent)
                    try? fm.copyItem(at: destURL, to: backupDest)
                    backupMap[destURL.path] = backupDest.path
                    try? fm.removeItem(at: destURL)
                }
                
                try rule.replacementData.write(to: destURL, options: .atomic)
                try? fm.setAttributes([.posixPermissions: 0o777], ofItemAtPath: destURL.path)
                injectedPaths.append(destURL.path)
            }
        } else {
            // Nạp file thường (.bytes, .dll, .json, v.v.)
            progressHandler(0.65, "Đang sao lưu và nạp \(patch.fileName)...")
            let subDir = patch.targetPath ?? "Documents/"
            let destFolderURL = URL(fileURLWithPath: liveContainer).appendingPathComponent(subDir)
            try fm.createDirectory(at: destFolderURL, withIntermediateDirectories: true)
            
            let destFileURL = destFolderURL.appendingPathComponent(patch.fileName)
            if fm.fileExists(atPath: destFileURL.path) {
                try? fm.createDirectory(at: backupBaseDir, withIntermediateDirectories: true)
                let backupDest = backupBaseDir.appendingPathComponent(destFileURL.lastPathComponent)
                try? fm.copyItem(at: destFileURL, to: backupDest)
                backupMap[destFileURL.path] = backupDest.path
                try? fm.removeItem(at: destFileURL)
            }
            
            try fm.copyItem(at: tempMainURL, to: destFileURL)
            try? fm.setAttributes([.posixPermissions: 0o777], ofItemAtPath: destFileURL.path)
            injectedPaths.append(destFileURL.path)
        }
        
        // 3. NẠP FILE LOCALCONFIG NẾU CÓ ĐÍNH KÈM
        if let configId = patch.configFileId {
            progressHandler(0.80, "Đang tải cấu hình localconfig.json...")
            let configToken = try await APIService.shared.requestDownloadToken(fileId: configId)
            if let configURL = URL(string: configToken.downloadUrl) {
                let (tempConfigURL, _) = try await URLSession.shared.download(from: configURL)
                let configName = patch.configFileName ?? "localconfig.json"
                let configSubDir = patch.configTargetPath ?? "Documents/"
                let configFolderURL = URL(fileURLWithPath: liveContainer).appendingPathComponent(configSubDir)
                try fm.createDirectory(at: configFolderURL, withIntermediateDirectories: true)
                
                let configDestURL = configFolderURL.appendingPathComponent(configName)
                if fm.fileExists(atPath: configDestURL.path) {
                    try? fm.createDirectory(at: backupBaseDir, withIntermediateDirectories: true)
                    let backupDest = backupBaseDir.appendingPathComponent("cfg_\(configDestURL.lastPathComponent)")
                    try? fm.copyItem(at: configDestURL, to: backupDest)
                    backupMap[configDestURL.path] = backupDest.path
                    try? fm.removeItem(at: configDestURL)
                }
                
                try fm.copyItem(at: tempConfigURL, to: configDestURL)
                try? fm.setAttributes([.posixPermissions: 0o777], ofItemAtPath: configDestURL.path)
                injectedPaths.append(configDestURL.path)
            }
        }
        
        // 4. Lưu lại danh sách file đã nạp vào manifest
        let record = InjectionRecord(
            bundleId: targetBundleId,
            timestamp: Date().timeIntervalSince1970,
            patchTitle: patch.displayName,
            injectedPaths: injectedPaths,
            backupMap: backupMap
        )
        saveInjectionRecord(record)
        
        progressHandler(1.0, "Đã nạp thành công vào Documents!")
    }
    
    // MARK: - Uninjector (Xóa Sạch Không Còn Dấu Vết)
    
    /// Xóa sạch toàn bộ các file vừa nạp và khôi phục file gốc nếu có sao lưu
    @discardableResult
    func uninjectPatch(game: Game) throws -> Int {
        let bundleId = game.bundleId
        guard let record = getInjectionRecord(bundleId: bundleId) else {
            // Không có record nhưng vẫn quét dọn folder backup nếu có
            if let container = GameDetectionService.shared.resolveAppContainer(bundleId: bundleId) {
                let backupDir = URL(fileURLWithPath: container).appendingPathComponent("Documents/Zev_Backups")
                try? fm.removeItem(at: backupDir)
            }
            return 0
        }
        
        var processedCount = 0
        
        // 1. Duyệt qua toàn bộ file đã nạp
        for filePath in record.injectedPaths {
            // Kiểm tra có bản sao lưu trước đó không
            if let backupPath = record.backupMap[filePath], fm.fileExists(atPath: backupPath) {
                // Khôi phục file gốc
                try? fm.removeItem(atPath: filePath)
                try? fm.moveItem(atPath: backupPath, toPath: filePath)
                try? fm.setAttributes([.posixPermissions: 0o777], ofItemAtPath: filePath)
                processedCount += 1
            } else {
                // Không có backup -> Xóa hoàn toàn file đã nạp
                if fm.fileExists(atPath: filePath) {
                    try? fm.removeItem(atPath: filePath)
                    processedCount += 1
                }
            }
        }
        
        // 2. Xóa sạch toàn bộ thư mục Zev_Backups
        if let container = GameDetectionService.shared.resolveAppContainer(bundleId: bundleId) {
            let backupDir = URL(fileURLWithPath: container).appendingPathComponent("Documents/Zev_Backups")
            try? fm.removeItem(at: backupDir)
        }
        
        // 3. Xóa bản ghi manifest
        clearInjectionRecord(bundleId: bundleId)
        
        return processedCount
    }
    
    // MARK: - Legacy Feature Patch Support
    
    /// Hỗ trợ nạp feature riêng lẻ nếu người dùng chọn theo danh mục
    func applyFeaturePatch(
        game: Game,
        feature: Feature,
        progressHandler: @escaping (Double, String) -> Void
    ) async throws {
        guard let fileId = feature.fileId else {
            throw PatchError.fileDownloadFailed("Chức năng này chưa có file được gán trên máy chủ.")
        }
        
        let patch = ActiveGamePatch(
            id: feature.id,
            displayName: feature.displayName,
            status: feature.status.rawValue,
            fileId: fileId,
            fileName: feature.fileName ?? "patch_file",
            fileSize: feature.fileSize ?? 0,
            targetPath: feature.targetPath ?? "Documents/",
            checksumSha256: feature.checksumSha256,
            filePassword: feature.filePassword,
            configFileId: feature.configFileId,
            configFileName: feature.configFileName,
            configFileSize: nil,
            configTargetPath: "Documents/"
        )
        
        try await applyActivePatch(game: game, patch: patch, progressHandler: progressHandler)
    }
    
    // MARK: - Setup Antiban (sing-box)
    
    func openSingboxOnAppStore() {
        if let url = URL(string: AppConfig.singboxAppStoreURL) {
            UIApplication.shared.open(url)
        }
    }
    
    func openSingboxApp() -> Bool {
        if let url = URL(string: "sing-box://") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return true
            }
        }
        return false
    }
}
