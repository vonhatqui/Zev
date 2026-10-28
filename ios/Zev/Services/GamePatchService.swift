import Foundation
import UIKit

// MARK: - GamePatchService
// Cơ chế áp dụng Patch từ 3105-2.0 cho game Free Fire Thường & MAX
// Hỗ trợ nạp file .3105 (giải mã & nạp các rule vào container), file .bytes, localConfig.json, cache file và cấu hình sing-box

enum PatchError: LocalizedError {
    case gameContainerNotFound(String)
    case fileDownloadFailed(String)
    case unsupportedFormat(String)
    case permissionDenied(String)
    case applyFailed(String)
    
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
        }
    }
}

final class GamePatchService {
    
    static let shared = GamePatchService()
    private init() {}
    
    private let fm = FileManager.default
    
    // MARK: - Apply Feature Patch
    
    /// Tải và nạp file bản vá của chức năng vào container của game
    func applyFeaturePatch(
        game: Game,
        feature: Feature,
        progressHandler: @escaping (Double, String) -> Void
    ) async throws {
        
        guard let fileId = feature.fileId else {
            throw PatchError.fileDownloadFailed("Chức năng này chưa có file được gán trên máy chủ.")
        }
        
        progressHandler(0.1, "Đang kết nối máy chủ...")
        
        // 1. Lấy download token từ API
        let tokenResponse = try await APIService.shared.requestDownloadToken(fileId: fileId)
        
        progressHandler(0.3, "Đang tải file bản vá...")
        
        // 2. Tải file về thư mục tạm
        guard let downloadURL = URL(string: tokenResponse.downloadUrl) else {
            throw PatchError.fileDownloadFailed("URL tải về không hợp lệ.")
        }
        
        let (tempLocalURL, _) = try await URLSession.shared.download(from: downloadURL)
        let fileData = try Data(contentsOf: tempLocalURL)
        
        let targetBundleId = game.bundleId
        let originalFilename = feature.fileName ?? "patch_file"
        
        // Xử lý đặc biệt cho cấu hình Antiban (sing-box)
        if feature.targetPath == "sing-box" || feature.slug.contains("singbox") || feature.slug.contains("antiban") {
            progressHandler(0.7, "Đang lưu cấu hình Antiban...")
            try handleSingboxConfig(tempFileURL: tempLocalURL, filename: originalFilename)
            progressHandler(1.0, "Đã lưu cấu hình Antiban thành công!")
            return
        }
        
        progressHandler(0.6, "Đang kiểm tra định dạng và kích hoạt container...")
        
        // 3. KIỂM TRA NẾU LÀ GÓI .3105 (3105PATCH)
        if PatchPackageCodec.is3105Package(data: fileData) {
            progressHandler(0.7, "Đang giải mã gói .3105...")
            let decoded = try PatchPackageCodec.decode(fileData, password: nil)
            
            progressHandler(0.85, "Đang nạp các file trong gói vào game...")
            var appliedCount = 0
            
            for rule in decoded.project.rules {
                let ruleBundle = rule.bundleID.isEmpty ? targetBundleId : rule.bundleID
                guard let containerRoot = GameDetectionService.shared.resolveAppContainer(bundleId: ruleBundle) else {
                    throw PatchError.gameContainerNotFound(ruleBundle)
                }
                
                let destURL = URL(fileURLWithPath: containerRoot).appendingPathComponent(rule.relativePath)
                try fm.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                
                // Sao lưu file cũ nếu có
                if fm.fileExists(atPath: destURL.path) {
                    let backupDir = URL(fileURLWithPath: containerRoot).appendingPathComponent("Documents/Zev_Backups/\(Int(Date().timeIntervalSince1970))")
                    try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
                    let backupDest = backupDir.appendingPathComponent(destURL.lastPathComponent)
                    try? fm.copyItem(at: destURL, to: backupDest)
                    try? fm.removeItem(at: destURL)
                }
                
                // Ghi dữ liệu giải mã vào vị trí đích
                try rule.replacementData.write(to: destURL, options: .atomic)
                try? fm.setAttributes([.posixPermissions: 0o777], ofItemAtPath: destURL.path)
                appliedCount += 1
            }
            
            progressHandler(1.0, "Đã nạp thành công \(appliedCount) file từ gói .3105 vào game!")
            return
        }
        
        // 4. NẠP FILE THÔNG THƯỜNG (.bytes, .json, .plist, v.v.)
        guard let liveContainer = GameDetectionService.shared.resolveAppContainer(bundleId: targetBundleId) else {
            throw PatchError.gameContainerNotFound(targetBundleId)
        }
        
        progressHandler(0.85, "Đang ghi đè file vào container game...")
        let destinationSubdir = feature.targetPath ?? "Documents/"
        let destFolderURL = URL(fileURLWithPath: liveContainer).appendingPathComponent(destinationSubdir)
        try fm.createDirectory(at: destFolderURL, withIntermediateDirectories: true)
        
        let targetDestFile = destFolderURL.appendingPathComponent(originalFilename)
        if fm.fileExists(atPath: targetDestFile.path) {
            let backupDir = URL(fileURLWithPath: liveContainer).appendingPathComponent("Documents/Zev_Backups/\(Int(Date().timeIntervalSince1970))")
            try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
            let backupDest = backupDir.appendingPathComponent(originalFilename)
            try? fm.copyItem(at: targetDestFile, to: backupDest)
            try? fm.removeItem(at: targetDestFile)
        }
        
        try fm.copyItem(at: tempLocalURL, to: targetDestFile)
        try? fm.setAttributes([.posixPermissions: 0o777], ofItemAtPath: targetDestFile.path)
        
        progressHandler(1.0, "Đã nạp trực tiếp vào container game thành công!")
    }
    
    // MARK: - Setup Antiban (sing-box)
    
    private func handleSingboxConfig(tempFileURL: URL, filename: String) throws {
        let documentsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let antibanDir = documentsDir.appendingPathComponent("Antiban", isDirectory: true)
        try fm.createDirectory(at: antibanDir, withIntermediateDirectories: true)
        
        let dest = antibanDir.appendingPathComponent(filename.isEmpty ? "antiban_config.json" : filename)
        try? fm.removeItem(at: dest)
        try fm.copyItem(at: tempFileURL, to: dest)
    }
    
    /// Mở link App Store để tải sing-box
    func openSingboxOnAppStore() {
        if let url = URL(string: "https://apps.apple.com/app/sing-box/id6451272673") {
            UIApplication.shared.open(url)
        }
    }
    
    /// Mở ứng dụng sing-box trên máy nếu đã cài
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
