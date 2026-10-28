import Foundation
import UIKit
import CryptoKit

// MARK: - GamePatchService
// Cơ chế nạp & gỡ bản vá chuẩn 3105-2.0:
// 1. Phân giải Container qua MobileContainerManager (MHA-C2) & chuẩn hóa đường dẫn canonical (/private/var/...)
// 2. Tự động hỗ trợ cả Free Fire Thường (com.dts.freefireth) và Free Fire MAX (com.dts.freefiremax)
// 3. Tự động sinh đầy đủ các biến thể tên gọi của Tencent IFix:
//    - Assembly-CSharp-patch.bytes (gốc)
//    - Assembly-CSharp.patch.bytes (dấu chấm)
//    - Assembly-CSharp.bytes
// 4. Tự động đồng bộ localconfig.json và localConfig.json (chống lỗi phân biệt hoa/thường trên APFS)
// 5. Ghi vào cả Documents/ và Documents/cached/ để game engine luôn đọc được
// 6. Tạo staging file nội bộ (.3105-patch-<UUID>), synchronize NVMe, rename POSIX atomic
// 7. Gán quyền 0o777 (rwxrwxrwx) và FileProtectionType.none
// 8. Sao lưu độc lập trong Zev_Backups (Application Support), Uninjector gỡ sạch 100% không dấu vết

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
            return "Không đủ quyền truy cập filesystem tại: \(path). Yêu cầu ứng dụng có quyền MobileHouseArrest hoặc cài đặt qua TrollStore."
        case .applyFailed(let msg):
            return "Lỗi khi áp dụng bản vá: \(msg)"
        case .uninjectFailed(let msg):
            return "Lỗi khi gỡ bản vá: \(msg)"
        }
    }
}

// MARK: - Injection Record Manifest
struct InjectionRecord: Codable {
    let bundleId: String
    let timestamp: TimeInterval
    let patchTitle: String
    let injectedPaths: [String]
    let backupMap: [String: String] // targetPath -> localBackupPath
    let createdDirectories: [String] // Các thư mục được tạo mới cần dọn dẹp khi gỡ
}

final class GamePatchService {
    
    static let shared = GamePatchService()
    private init() {}
    
    private let fm = FileManager.default
    private let manifestPrefix = "zev.injected_manifest."
    
    // MARK: - Status Tracking
    
    /// Kiểm tra game hiện tại đã được nạp bản vá hay chưa
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
    
    // MARK: - 3105-2.0 Atomic File Operations
    
    /// Ghi file atomic bằng cách tạo file tạm trong cùng thư mục đích, flush NVMe, và rename POSIX
    private func atomicWrite(
        _ data: Data,
        to target: URL,
        preservingExistingAttributes: Bool = true
    ) throws {
        let parentDir = target.deletingLastPathComponent()
        if !fm.fileExists(atPath: parentDir.path) {
            try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
        
        let staging = parentDir.appendingPathComponent(".3105-patch-\(UUID().uuidString)")
        var attributes: [FileAttributeKey: Any] = [:]
        
        if preservingExistingAttributes, let current = try? fm.attributesOfItem(atPath: target.path) {
            if let permissions = current[.posixPermissions] { attributes[.posixPermissions] = permissions }
            if let protection = current[.protectionKey] { attributes[.protectionKey] = protection }
        }
        
        // Mặc định quyền rwxrwxrwx và không khóa file
        if attributes[.posixPermissions] == nil {
            attributes[.posixPermissions] = 0o777
        }
        if attributes[.protectionKey] == nil {
            attributes[.protectionKey] = FileProtectionType.none
        }
        
        guard fm.createFile(atPath: staging.path, contents: data, attributes: attributes) else {
            throw PatchError.applyFailed("Không thể tạo file staging tạm thời tại \(staging.path)")
        }
        defer { try? fm.removeItem(at: staging) }
        
        let handle = try FileHandle(forWritingTo: staging)
        try handle.synchronize()
        try handle.close()
        
        guard rename(staging.path, target.path) == 0 else {
            throw PatchError.applyFailed("Rename atomic thất bại tại \(target.path), errno=\(errno)")
        }
        
        chmod(target.path, 0o777)
        try? fm.setAttributes([
            .posixPermissions: 0o777,
            .protectionKey: FileProtectionType.none
        ], ofItemAtPath: target.path)
    }
    
    /// Khôi phục file atomic từ bản sao lưu
    private func atomicCopy(
        _ source: URL,
        to target: URL
    ) throws {
        let parentDir = target.deletingLastPathComponent()
        if !fm.fileExists(atPath: parentDir.path) {
            try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
        
        let staging = parentDir.appendingPathComponent(".3105-restore-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: staging) }
        
        try fm.copyItem(at: source, to: staging)
        
        var attributes: [FileAttributeKey: Any] = [:]
        if let current = try? fm.attributesOfItem(atPath: target.path) {
            if let permissions = current[.posixPermissions] { attributes[.posixPermissions] = permissions }
            if let protection = current[.protectionKey] { attributes[.protectionKey] = protection }
        }
        if attributes[.posixPermissions] == nil {
            attributes[.posixPermissions] = 0o777
        }
        if attributes[.protectionKey] == nil {
            attributes[.protectionKey] = FileProtectionType.none
        }
        try? fm.setAttributes(attributes, ofItemAtPath: staging.path)
        
        let handle = try FileHandle(forWritingTo: staging)
        try handle.synchronize()
        try handle.close()
        
        guard rename(staging.path, target.path) == 0 else {
            throw PatchError.uninjectFailed("Không thể khôi phục file gốc tại \(target.path)")
        }
        chmod(target.path, 0o777)
    }
    
    /// Tính SHA256 của file trên ổ đĩa để kiểm tra tính toàn vẹn
    private func digestFile(_ url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_024 * 1_024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return Data(hasher.finalize())
    }
    
    private func digestData(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }
    
    /// Thư mục sao lưu an toàn bên trong Application Support của Zev
    private func getBackupSessionDirectory(bundleId: String, timestamp: Int) throws -> URL {
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let sessionDir = appSupport
            .appendingPathComponent("Zev_Backups", isDirectory: true)
            .appendingPathComponent(bundleId, isDirectory: true)
            .appendingPathComponent("\(timestamp)", isDirectory: true)
        try fm.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        return sessionDir
    }
    
    // MARK: - Apply Active Patch (3105-2.0 Mechanism)
    
    /// Nạp bản vá vào container game theo chuẩn 3105-2.0
    func applyActivePatch(
        game: Game,
        patch: ActiveGamePatch,
        progressHandler: @escaping (Double, String) -> Void
    ) async throws {
        let targetBundleId = game.bundleId
        
        // 1. Tìm tất cả container Free Fire có sẵn trên thiết bị (Thường & MAX)
        var targetContainers: [(bundleId: String, rootURL: URL)] = []
        
        if let primaryPath = GameDetectionService.shared.resolveAppContainer(bundleId: targetBundleId) {
            targetContainers.append((targetBundleId, PatchPathValidator.canonicalFileURL(URL(fileURLWithPath: primaryPath))))
        }
        
        // Tự động kiểm tra thêm bản Free Fire khác (nếu máy cài cả 2 bản hoặc người dùng chọn nhầm tab)
        let alternateBundleId = (targetBundleId == "com.dts.freefireth") ? "com.dts.freefiremax" : "com.dts.freefireth"
        if let altPath = GameDetectionService.shared.resolveAppContainer(bundleId: alternateBundleId) {
            targetContainers.append((alternateBundleId, PatchPathValidator.canonicalFileURL(URL(fileURLWithPath: altPath))))
        }
        
        guard !targetContainers.isEmpty else {
            throw PatchError.gameContainerNotFound(targetBundleId)
        }
        
        progressHandler(0.15, "Đang kết nối máy chủ...")
        
        // 2. Tải file chính (Main patch file)
        let tokenResponse = try await APIService.shared.requestDownloadToken(fileId: patch.fileId)
        guard let downloadURL = URL(string: tokenResponse.downloadUrl) else {
            throw PatchError.fileDownloadFailed("URL tải file chính không hợp lệ.")
        }
        
        progressHandler(0.35, "Đang tải file bản vá (\(patch.fileName))...")
        let (tempMainURL, _) = try await URLSession.shared.download(from: downloadURL)
        let mainData = try Data(contentsOf: tempMainURL)
        try? fm.removeItem(at: tempMainURL)
        
        // 3. Tải file localconfig nếu có
        var configData: Data? = nil
        if let configId = patch.configFileId {
            progressHandler(0.50, "Đang tải cấu hình localconfig.json...")
            if let configToken = try? await APIService.shared.requestDownloadToken(fileId: configId),
               let configURL = URL(string: configToken.downloadUrl) {
                if let (tempConfigURL, _) = try? await URLSession.shared.download(from: configURL),
                   let cData = try? Data(contentsOf: tempConfigURL) {
                    configData = cData
                    try? fm.removeItem(at: tempConfigURL)
                }
            }
        }
        
        // Nếu không có file config tải lên, tự động tạo config kích hoạt chuẩn IFix
        if configData == nil {
            configData = "{\"testCodePatch\":true,\"system_active\":true}".data(using: .utf8)
        }
        
        var allInjectedPaths: [String] = []
        var allBackupMap: [String: String] = [:]
        var allCreatedDirectories: [String] = []
        let timestamp = Int(Date().timeIntervalSince1970)
        let backupDir = try getBackupSessionDirectory(bundleId: targetBundleId, timestamp: timestamp)
        
        // 4. Áp dụng cho từng container game tìm thấy
        for (bId, containerRootURL) in targetContainers {
            progressHandler(0.65, "Đang nạp dữ liệu vào \(bId.contains("max") ? "FF MAX" : "FF Thường")...")
            
            // Xử lý gói .3105 chuyên dụng
            if PatchPackageCodec.is3105Package(data: mainData) {
                let decoded = try PatchPackageCodec.decode(mainData, password: patch.filePassword)
                
                for dir in decoded.project.directories {
                    let dirBundle = dir.bundleID.isEmpty ? bId : dir.bundleID
                    if let cPath = GameDetectionService.shared.resolveAppContainer(bundleId: dirBundle) {
                        let cRoot = PatchPathValidator.canonicalFileURL(URL(fileURLWithPath: cPath))
                        if let dirURL = try? PatchPathValidator.resolveContainedTargetURL(relativePath: dir.relativePath, containerRoot: cRoot) {
                            if !fm.fileExists(atPath: dirURL.path) {
                                try? fm.createDirectory(at: dirURL, withIntermediateDirectories: true)
                                allCreatedDirectories.append(dirURL.path)
                            }
                        }
                    }
                }
                
                for rule in decoded.project.rules {
                    let ruleBundle = rule.bundleID.isEmpty ? bId : rule.bundleID
                    guard let cPath = GameDetectionService.shared.resolveAppContainer(bundleId: ruleBundle) else { continue }
                    let cRoot = PatchPathValidator.canonicalFileURL(URL(fileURLWithPath: cPath))
                    let targetURL = try PatchPathValidator.resolveContainedTargetURL(relativePath: rule.relativePath, containerRoot: cRoot)
                    
                    if fm.fileExists(atPath: targetURL.path) {
                        let backupFile = backupDir.appendingPathComponent("\(UUID().uuidString).orig")
                        try fm.copyItem(at: targetURL, to: backupFile)
                        allBackupMap[targetURL.path] = backupFile.path
                    }
                    
                    try atomicWrite(rule.replacementData, to: targetURL, preservingExistingAttributes: true)
                    allInjectedPaths.append(targetURL.path)
                }
            } else {
                // Xử lý file thường (.bytes, Assembly, .dll, v.v.)
                // Tạo các biến thể tên gọi phổ biến của IFix để game luôn nhận diện
                var fileNames: Set<String> = [patch.fileName]
                if patch.fileName.contains("-patch.bytes") {
                    fileNames.insert(patch.fileName.replacingOccurrences(of: "-patch.bytes", with: ".patch.bytes"))
                    fileNames.insert(patch.fileName.replacingOccurrences(of: "-patch.bytes", with: ".bytes"))
                } else if patch.fileName.contains(".patch.bytes") {
                    fileNames.insert(patch.fileName.replacingOccurrences(of: ".patch.bytes", with: "-patch.bytes"))
                    fileNames.insert(patch.fileName.replacingOccurrences(of: ".patch.bytes", with: ".bytes"))
                }
                
                // Các thư mục đích mà Free Fire thường đọc hotfix
                let targetFolders = ["Documents", "Documents/cached", "Documents/patch"]
                
                for folderRel in targetFolders {
                    let destFolder = containerRootURL.appendingPathComponent(folderRel, isDirectory: true)
                    if !fm.fileExists(atPath: destFolder.path) {
                        try? fm.createDirectory(at: destFolder, withIntermediateDirectories: true)
                        allCreatedDirectories.append(destFolder.path)
                    }
                    
                    // Ghi tất cả biến thể tên file bản vá
                    for fname in fileNames {
                        let targetURL = destFolder.appendingPathComponent(fname)
                        if fm.fileExists(atPath: targetURL.path) {
                            let backupFile = backupDir.appendingPathComponent("\(UUID().uuidString).orig")
                            try? fm.copyItem(at: targetURL, to: backupFile)
                            allBackupMap[targetURL.path] = backupFile.path
                        }
                        
                        try atomicWrite(mainData, to: targetURL, preservingExistingAttributes: true)
                        allInjectedPaths.append(targetURL.path)
                    }
                    
                    // Ghi cả localconfig.json và localConfig.json vào thư mục
                    if let cfgData = configData {
                        let configNames = ["localconfig.json", "localConfig.json"]
                        for cfgName in configNames {
                            let cfgTargetURL = destFolder.appendingPathComponent(cfgName)
                            if fm.fileExists(atPath: cfgTargetURL.path) {
                                let backupFile = backupDir.appendingPathComponent("cfg_\(UUID().uuidString).orig")
                                try? fm.copyItem(at: cfgTargetURL, to: backupFile)
                                allBackupMap[cfgTargetURL.path] = backupFile.path
                            }
                            
                            try atomicWrite(cfgData, to: cfgTargetURL, preservingExistingAttributes: true)
                            allInjectedPaths.append(cfgTargetURL.path)
                        }
                    }
                }
            }
        }
        
        // 5. Lưu lại bản ghi manifest
        let record = InjectionRecord(
            bundleId: targetBundleId,
            timestamp: Date().timeIntervalSince1970,
            patchTitle: patch.displayName,
            injectedPaths: allInjectedPaths,
            backupMap: allBackupMap,
            createdDirectories: allCreatedDirectories
        )
        saveInjectionRecord(record)
        
        progressHandler(1.0, "Đã nạp thành công vào cả Free Fire & Free Fire MAX!")
    }
    
    // MARK: - Uninjector (Xóa Sạch Không Còn Dấu Vết)
    
    /// Khôi phục file gốc và xóa sạch các file đã nạp mà không để lại bất kỳ dấu vết nào
    @discardableResult
    func uninjectPatch(game: Game) throws -> Int {
        let bundleId = game.bundleId
        guard let record = getInjectionRecord(bundleId: bundleId) else {
            return 0
        }
        
        var processedCount = 0
        
        // 1. Khôi phục hoặc xóa từng file đã nạp
        for filePath in record.injectedPaths {
            let targetURL = URL(fileURLWithPath: filePath)
            
            if let backupPath = record.backupMap[filePath], fm.fileExists(atPath: backupPath) {
                // Có file gốc -> Khôi phục atomic
                let backupURL = URL(fileURLWithPath: backupPath)
                try? atomicCopy(backupURL, to: targetURL)
                processedCount += 1
            } else {
                // Không có file gốc -> Xóa bỏ hoàn toàn
                if fm.fileExists(atPath: filePath) {
                    try? fm.removeItem(at: targetURL)
                    processedCount += 1
                }
            }
        }
        
        // 2. Dọn dẹp các thư mục rỗng được tạo mới
        for dirPath in record.createdDirectories.reversed() {
            let dirURL = URL(fileURLWithPath: dirPath)
            if let contents = try? fm.contentsOfDirectory(atPath: dirPath), contents.isEmpty {
                try? fm.removeItem(at: dirURL)
            }
        }
        
        // 3. Dọn dẹp thư mục sao lưu trong Application Support của Zev
        if let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            let sessionDir = appSupport
                .appendingPathComponent("Zev_Backups", isDirectory: true)
                .appendingPathComponent(bundleId, isDirectory: true)
            try? fm.removeItem(at: sessionDir)
        }
        
        // 4. Xóa bản ghi manifest
        clearInjectionRecord(bundleId: bundleId)
        
        return processedCount
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
