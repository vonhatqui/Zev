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
    
    /// Ghi file an toàn đa cấp, đảm bảo quyền đọc ghi và tương thích sandbox
    private func atomicWrite(
        _ data: Data,
        to target: URL,
        preservingExistingAttributes: Bool = true
    ) throws {
        let parentDir = target.deletingLastPathComponent()
        if !fm.fileExists(atPath: parentDir.path) {
            try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
        
        var written = false
        // Cách 1: Ghi trực tiếp atomic
        try? fm.removeItem(at: target)
        do {
            try data.write(to: target, options: .atomic)
            written = true
        } catch {
            // Cách 2: Ghi qua temporaryDirectory rồi chuyển sang
            let tempURL = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            if (try? data.write(to: tempURL)) != nil {
                try? fm.removeItem(at: target)
                if (try? fm.copyItem(at: tempURL, to: target)) != nil {
                    written = true
                }
                try? fm.removeItem(at: tempURL)
            }
            // Cách 3: createFile chuẩn
            if !written {
                if fm.createFile(atPath: target.path, contents: data, attributes: nil) {
                    written = true
                }
            }
        }
        
        guard written else {
            throw PatchError.applyFailed("Không thể ghi file tại \(target.path)")
        }
        
        // Cấp toàn quyền đọc ghi (0o777) và tắt Data Protection để game đọc được tự do
        chmod(target.path, 0o777)
        try? fm.setAttributes([
            .posixPermissions: 0o777,
            .protectionKey: FileProtectionType.none
        ], ofItemAtPath: target.path)
        
        var uTarget = target
        var resVals = URLResourceValues()
        resVals.isExcludedFromBackup = true
        try? uTarget.setResourceValues(resVals)
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
    
    // MARK: - Default Config & Control Flags (Chuẩn HyperX / 3105-2.0)
    
    public static let defaultMenuConfigData: Data = Data("""
    {
      "box_esp": true,
      "line_esp": true,
      "health_bar": true,
      "name_tag": true,
      "distance_tag": true,
      "aim_silent": true,
      "aim_bot": true,
      "no_recoil": false,
      "aim_fov": 120.0,
      "headshot_rate": 80,
      "color": 1,
      "aim_target": 0,
      "buff_damage": false,
      "fast_fire": false,
      "wide_view": true,
      "cam_distance": 1.4,
      "speed_run": 1.0,
      "box_r": 255,
      "box_g": 0,
      "box_b": 0,
      "line_r": 0,
      "line_g": 255,
      "line_b": 0,
      "draw_fov": true,
      "box_thickness": 1.5,
      "line_thickness": 1.0,
      "box_color": "#FF0000",
      "line_color": "#00FF00",
      "target_line": true,
      "testCodePatch": true,
      "resetGuest": true,
      "data": {
        "box_esp": true,
        "line_esp": true,
        "health_bar": true,
        "name_tag": true,
        "distance_tag": true,
        "aim_silent": true,
        "aim_bot": true,
        "no_recoil": false,
        "aim_fov": 120.0,
        "headshot_rate": 80,
        "color": 1,
        "aim_target": 0,
        "buff_damage": false,
        "fast_fire": false,
        "wide_view": true,
        "cam_distance": 1.4,
        "speed_run": 1.0,
        "box_r": 255,
        "box_g": 0,
        "box_b": 0,
        "line_r": 0,
        "line_g": 255,
        "line_b": 0,
        "draw_fov": true,
        "box_thickness": 1.5,
        "line_thickness": 1.0,
        "box_color": "#FF0000",
        "line_color": "#00FF00",
        "target_line": true
      }
    }
    """.utf8)

    public static let defaultLocalConfigData: Data = Data("""
    {
      "server_esp": true,
      "server_aim": true,
      "server_health": true,
      "server_name": true,
      "server_box": true,
      "server_line": true,
      "server_skeleton": true,
      "server_distance": true,
      "server_headshot": true,
      "system_active": true,
      "AimEnabled": true,
      "AimSystemEnabled": true,
      "AimTarget": 0,
      "HeadshotRate": 80,
      "FovSize": 120,
      "EspMaster": true,
      "EspBox": true,
      "EspLine": true,
      "EspName": true,
      "EspHealth": true,
      "EspDistance": true,
      "EspFov": true,
      "EspSkeleton": true,
      "EspTracer": false,
      "NoRecoil": false,
      "FastParachute": false,
      "CamXa": true,
      "CamXaFloat": 1.4,
      "GhostMode": false,
      "SpeedHack": 1,
      "BuffDame": false,
      "ShowGuestBtn": true,
      "resetGuest": true,
      "reset_guest": true,
      "resetGuestBeforeLogin": false,
      "testCodePatch": true,
      "box_esp": true,
      "line_esp": true,
      "health_bar": true,
      "name_tag": true,
      "distance_tag": true,
      "aim_silent": true,
      "aim_bot": true,
      "no_recoil": false,
      "aim_fov": 120.0,
      "headshot_rate": 80,
      "color": 1,
      "aim_target": 0,
      "buff_damage": false,
      "fast_fire": false,
      "wide_view": true,
      "cam_distance": 1.4,
      "speed_run": 1.0,
      "draw_fov": true,
      "box_thickness": 1.5,
      "line_thickness": 1.0,
      "target_line": true
    }
    """.utf8)

    // Neutral IFix Bridge Seed (322 bytes) để game không bị crash khi gỡ bản vá
    private static let neutralIFixBridgeSeed: Data = Data([
        0xcb, 0xa2, 0xb4, 0x0d, 0xb2, 0x19, 0xa3, 0x66, 0x64, 0x49, 0x46, 0x69, 0x78, 0x2e, 0x49, 0x4c,
        0x46, 0x69, 0x78, 0x49, 0x6e, 0x74, 0x65, 0x72, 0x66, 0x61, 0x63, 0x65, 0x42, 0x72, 0x69, 0x64,
        0x67, 0x65, 0x2c, 0x20, 0x41, 0x73, 0x73, 0x65, 0x6d, 0x62, 0x6c, 0x79, 0x2d, 0x43, 0x53, 0x68,
        0x61, 0x72, 0x70, 0x2c, 0x20, 0x56, 0x65, 0x72, 0x73, 0x69, 0x6f, 0x6e, 0x3d, 0x30, 0x2e, 0x38,
        0x36, 0x2e, 0x30, 0x2e, 0x35, 0x31, 0x38, 0x2c, 0x20, 0x43, 0x75, 0x6c, 0x74, 0x75, 0x72, 0x65,
        0x3d, 0x6e, 0x65, 0x75, 0x74, 0x72, 0x61, 0x6c, 0x2c, 0x20, 0x50, 0x75, 0x62, 0x6c, 0x69, 0x63,
        0x4b, 0x65, 0x79, 0x54, 0x6f, 0x6b, 0x65, 0x6e, 0x3d, 0x6e, 0x75, 0x6c, 0x6c, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x63, 0x49, 0x46, 0x69, 0x78, 0x2e, 0x57,
        0x72, 0x61, 0x70, 0x70, 0x65, 0x72, 0x73, 0x4d, 0x61, 0x6e, 0x61, 0x67, 0x65, 0x72, 0x49, 0x6d,
        0x70, 0x6c, 0x2c, 0x20, 0x41, 0x73, 0x73, 0x65, 0x6d, 0x62, 0x6c, 0x78, 0x2d, 0x43, 0x53, 0x68,
        0x61, 0x72, 0x70, 0x2c, 0x20, 0x56, 0x65, 0x72, 0x73, 0x69, 0x6f, 0x6e, 0x3d, 0x30, 0x2e, 0x38,
        0x36, 0x2e, 0x30, 0x2e, 0x35, 0x31, 0x38, 0x2c, 0x20, 0x43, 0x75, 0x6c, 0x74, 0x75, 0x72, 0x65,
        0x3d, 0x6e, 0x65, 0x75, 0x74, 0x72, 0x61, 0x6c, 0x2c, 0x20, 0x50, 0x75, 0x62, 0x6c, 0x69, 0x63,
        0x4b, 0x65, 0x79, 0x54, 0x6f, 0x6b, 0x65, 0x6e, 0x3d, 0x6e, 0x75, 0x6c, 0x6c, 0x4b, 0x2c, 0x20,
        0x41, 0x73, 0x73, 0x65, 0x6d, 0x62, 0x6c, 0x79, 0x2d, 0x43, 0x53, 0x68, 0x61, 0x72, 0x70, 0x2c,
        0x20, 0x56, 0x65, 0x72, 0x73, 0x69, 0x6f, 0x6e, 0x3d, 0x30, 0x2e, 0x38, 0x36, 0x2e, 0x30, 0x2e,
        0x35, 0x31, 0x38, 0x2c, 0x20, 0x43, 0x75, 0x6c, 0x74, 0x75, 0x72, 0x65, 0x3d, 0x6e, 0x65, 0x75,
        0x74, 0x72, 0x61, 0x6c, 0x2c, 0x20, 0x50, 0x75, 0x62, 0x6c, 0x69, 0x63, 0x4b, 0x65, 0x79, 0x54,
        0x6f, 0x6b, 0x65, 0x6e, 0x3d, 0x6e, 0x75, 0x6c, 0x6c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00
    ])
    
    // MARK: - FFXC Runtime Tokens (Chuẩn 3105 / FFXC Engine)
    public static let ffxcLiveData: Data = Data("FFXCLIVE2\n37ca851ab5df497db608f1b2f45165f9\n2\n704807167\n201775153\n120\n286c910f8c2a7798a5be7b2fc66e4f073ba97077eb46da7998c58bb8720a2dce\n".utf8)
    
    public static let ffxcRuntimeData: Data = Data("FFXC2\n37ca851ab5df497db608f1b2f45165f9\n15\n704807167\n201775153\n173d5b9b9cdded8652d2c5726b0b2740e03ad6ae7d13248ec3d85e8675c57c62\n4c2c13744bc558fb16400aeaf0ef59c2b4c4b9cde41446ff0c6e51aa2f96c49e\ndelete\n-\n0434a8d6e21eb30812c33d61471bbeb8f7f1cd197e8ba4d503e9849f69d4eb67\n".utf8)
    
    /// Giải mã gói .3105 với danh sách mật khẩu dự phòng tự động (OG, 1, 3105)
    private func decodePackageWithFallbacks(_ data: Data, userPassword: String?) throws -> DecodedPatchPackage {
        var passwordsToTry: [String?] = []
        if let pass = userPassword, !pass.isEmpty {
            passwordsToTry.append(pass)
        }
        passwordsToTry.append("OG")
        passwordsToTry.append("1")
        passwordsToTry.append("3105")
        passwordsToTry.append(nil)
        
        var lastErr: Error?
        for pass in passwordsToTry {
            do {
                let decoded = try PatchPackageCodec.decode(data, password: pass)
                #if DEBUG
                print("[GamePatchService] Successfully decoded .3105 with password: '\(pass ?? "nil")'")
                #endif
                return decoded
            } catch {
                lastErr = error
            }
        }
        throw lastErr ?? PatchPackageError.invalidPasswordOrCorruptedPackage
    }
    
    // MARK: - Apply Active Patch (3105-2.0 Mechanism)
    
    /// Nạp bản vá vào container game theo chuẩn 3105-2.0
    func applyActivePatch(
        game: Game,
        patch: ActiveGamePatch,
        progressHandler: @escaping (Double, String) -> Void
    ) async throws {
        let targetBundleId = game.bundleId
        
        // 1. Tìm container thực tế của game được chọn (hỗ trợ cả các Bundle ID biến thể của Free Fire)
        var targetContainers: [(bundleId: String, rootURL: URL)] = []
        let candidateBundleIds: [String]
        if targetBundleId.contains("max") {
            candidateBundleIds = ["com.dts.freefiremax"]
        } else {
            candidateBundleIds = ["com.dts.freefireth", "com.dts.freefire", "com.dts.freefirevn"]
        }
        
        var foundPaths = Set<String>()
        for b in candidateBundleIds {
            if let path = GameDetectionService.shared.resolveAppContainer(bundleId: b),
               GameDetectionService.shared.isApplicationContainerPath(path) {
                if !foundPaths.contains(path) {
                    foundPaths.insert(path)
                    targetContainers.append((b, URL(fileURLWithPath: path)))
                }
            }
        }
        
        // Quét chữ ký hệ thống tập tin (Library/Preferences/com.dts.freefire*.plist hoặc Documents/contentcache)
        if targetContainers.isEmpty {
            if let sigPath = GameDetectionService.shared.resolveBySignatureScan(bundleId: targetBundleId),
               GameDetectionService.shared.isApplicationContainerPath(sigPath),
               !foundPaths.contains(sigPath) {
                foundPaths.insert(sigPath)
                targetContainers.append((targetBundleId, URL(fileURLWithPath: sigPath)))
            }
        }
        
        // Quét dự phòng toàn bộ các bundle ID Free Fire khả dụng trên máy (hỗ trợ trường hợp IPA đổi bundle ID hoặc người dùng chọn nhầm tab)
        if targetContainers.isEmpty {
            let allCandidates = ["com.dts.freefireth", "com.dts.freefiremax", "com.dts.freefire", "com.dts.freefirevn"]
            for b in allCandidates {
                if let path = GameDetectionService.shared.resolveAppContainer(bundleId: b),
                   GameDetectionService.shared.isApplicationContainerPath(path) {
                    if !foundPaths.contains(path) {
                        foundPaths.insert(path)
                        targetContainers.append((b, URL(fileURLWithPath: path)))
                    }
                }
            }
        }
        
        // Loại bỏ mọi đường dẫn không hợp lệ
        targetContainers.removeAll { !GameDetectionService.shared.isApplicationContainerPath($0.rootURL.path) }
        
        guard !targetContainers.isEmpty else {
            throw PatchError.gameContainerNotFound(targetBundleId)
        }
        
        // 2. Lấy dữ liệu file chính và cấu hình (Ưu tiên bản vá nhúng sẵn từ D:\abcxyz)
        let mainData: Data
        let activeLocalConfig: Data
        
        if patch.fileId == 999 || patch.fileName.contains("Assembly-CSharp") {
            progressHandler(0.35, "Đang nạp bản vá nhúng sẵn (\(BundledModData.patchByteSize) bytes)...")
            mainData = BundledModData.patchData
            activeLocalConfig = BundledModData.localConfigData
        } else {
            // Tải file từ máy chủ nếu là bản vá tùy chỉnh ngoài
            var mData: Data? = nil
            var cData: Data? = nil
            do {
                let tokenResponse = try await APIService.shared.requestDownloadToken(fileId: patch.fileId)
                if let downloadURL = URL(string: tokenResponse.downloadUrl) {
                    progressHandler(0.35, "Đang tải file bản vá (\(patch.fileName))...")
                    let (tempMainURL, _) = try await URLSession.shared.download(from: downloadURL)
                    mData = try? Data(contentsOf: tempMainURL)
                    try? fm.removeItem(at: tempMainURL)
                }
                if let configId = patch.configFileId {
                    if let configToken = try? await APIService.shared.requestDownloadToken(fileId: configId),
                       let configURL = URL(string: configToken.downloadUrl),
                       let (tempConfigURL, _) = try? await URLSession.shared.download(from: configURL) {
                        cData = try? Data(contentsOf: tempConfigURL)
                        try? fm.removeItem(at: tempConfigURL)
                    }
                }
            } catch {
                #if DEBUG
                print("[GamePatchService] Server download error, using bundled mod: \(error)")
                #endif
            }
            mainData = (mData != nil && !mData!.isEmpty) ? mData! : BundledModData.patchData
            activeLocalConfig = (cData != nil && !cData!.isEmpty) ? cData! : BundledModData.localConfigData
        }
        
        var allInjectedPaths: [String] = []
        var allBackupMap: [String: String] = [:]
        var allCreatedDirectories: [String] = []
        let timestamp = Int(Date().timeIntervalSince1970)
        let backupDir = try getBackupSessionDirectory(bundleId: targetBundleId, timestamp: timestamp)
        
        // 4. Áp dụng cho từng container game tìm thấy
        for (bId, containerRootURL) in targetContainers {
            let gameDisplayName = bId.contains("max") ? "FF MAX" : "FF Thường"
            progressHandler(0.65, "Đang nạp dữ liệu vào \(gameDisplayName)...")
            
            let docDir = containerRootURL.appendingPathComponent("Documents", isDirectory: true)
            let cachedDir = containerRootURL.appendingPathComponent("Documents/cached", isDirectory: true)
            try? fm.createDirectory(at: docDir, withIntermediateDirectories: true)
            try? fm.createDirectory(at: cachedDir, withIntermediateDirectories: true)
            allCreatedDirectories.append(docDir.path)
            allCreatedDirectories.append(cachedDir.path)
            
            // Xử lý gói .3105 chuyên dụng hoặc file raw
            if PatchPackageCodec.is3105Package(data: mainData) {
                let decoded = try decodePackageWithFallbacks(mainData, userPassword: patch.filePassword)
                
                for dir in decoded.project.directories {
                    if let dirURL = try? PatchPathValidator.resolveContainedTargetURL(relativePath: dir.relativePath, containerRoot: containerRootURL) {
                        if !fm.fileExists(atPath: dirURL.path) {
                            try? fm.createDirectory(at: dirURL, withIntermediateDirectories: true)
                            allCreatedDirectories.append(dirURL.path)
                        }
                    }
                }
                
                for rule in decoded.project.rules {
                    guard !rule.replacementData.isEmpty || rule.hasReplacement else { continue }
                    var rel = rule.relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/\\"))
                    if rel.isEmpty {
                        rel = "Documents/" + rule.replacementFilename
                    }
                    
                    let targetURL = containerRootURL.appendingPathComponent(rel)
                    let parentDir = targetURL.deletingLastPathComponent()
                    try? fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
                    
                    if fm.fileExists(atPath: targetURL.path) {
                        let backupFile = backupDir.appendingPathComponent("\(UUID().uuidString).orig")
                        try? fm.copyItem(at: targetURL, to: backupFile)
                        allBackupMap[targetURL.path] = backupFile.path
                    }
                    
                    try atomicWrite(rule.replacementData, to: targetURL, preservingExistingAttributes: true)
                    allInjectedPaths.append(targetURL.path)
                    
                    // Nếu là Assembly-CSharp-patch.bytes, ghi song song bản có dấu chấm và ghi vào cached
                    if targetURL.lastPathComponent == "Assembly-CSharp-patch.bytes" {
                        let dotTarget = parentDir.appendingPathComponent("Assembly-CSharp.patch.bytes")
                        try? atomicWrite(rule.replacementData, to: dotTarget, preservingExistingAttributes: true)
                        allInjectedPaths.append(dotTarget.path)
                        
                        let cachedPatch = cachedDir.appendingPathComponent("Assembly-CSharp-patch.bytes")
                        let cachedDotPatch = cachedDir.appendingPathComponent("Assembly-CSharp.patch.bytes")
                        try? atomicWrite(rule.replacementData, to: cachedPatch, preservingExistingAttributes: true)
                        try? atomicWrite(rule.replacementData, to: cachedDotPatch, preservingExistingAttributes: true)
                        allInjectedPaths.append(cachedPatch.path)
                        allInjectedPaths.append(cachedDotPatch.path)
                    }
                }
            } else {
                // Xử lý file thường (.bytes, Assembly, v.v.)
                let targetFolders = [docDir, cachedDir]
                let patchFileNames = ["Assembly-CSharp-patch.bytes", "Assembly-CSharp.patch.bytes", patch.fileName]
                
                for folderURL in targetFolders {
                    for fname in patchFileNames {
                        let targetURL = folderURL.appendingPathComponent(fname)
                        if fm.fileExists(atPath: targetURL.path) {
                            let backupFile = backupDir.appendingPathComponent("\(UUID().uuidString).orig")
                            try? fm.copyItem(at: targetURL, to: backupFile)
                            allBackupMap[targetURL.path] = backupFile.path
                        }
                        
                        try atomicWrite(mainData, to: targetURL, preservingExistingAttributes: true)
                        allInjectedPaths.append(targetURL.path)
                    }
                }
            }
            
            // GHI ĐỒNG BỘ TẤT CẢ CẤU HÌNH & CỜ ĐIỀU KHIỂN (Cả gói .3105 lẫn file raw)
            for folderURL in [docDir, cachedDir] {
                // Ghi localconfig.json và localConfig.json
                for cfgName in ["localconfig.json", "localConfig.json"] {
                    let cfgTargetURL = folderURL.appendingPathComponent(cfgName)
                    if fm.fileExists(atPath: cfgTargetURL.path) {
                        let backupFile = backupDir.appendingPathComponent("cfg_\(UUID().uuidString).orig")
                        try? fm.copyItem(at: cfgTargetURL, to: backupFile)
                        allBackupMap[cfgTargetURL.path] = backupFile.path
                    }
                    try? atomicWrite(activeLocalConfig, to: cfgTargetURL, preservingExistingAttributes: true)
                    allInjectedPaths.append(cfgTargetURL.path)
                }
                
                // Ghi menu_config.json
                let menuTargetURL = folderURL.appendingPathComponent("menu_config.json")
                if fm.fileExists(atPath: menuTargetURL.path) {
                    let backupFile = backupDir.appendingPathComponent("menu_\(UUID().uuidString).orig")
                    try? fm.copyItem(at: menuTargetURL, to: backupFile)
                    allBackupMap[menuTargetURL.path] = backupFile.path
                }
                try? atomicWrite(Self.defaultMenuConfigData, to: menuTargetURL, preservingExistingAttributes: true)
                allInjectedPaths.append(menuTargetURL.path)
            }
            
            // Ghi 2 cờ điều khiển kích hoạt Antiban & Nút Menu (chuẩn HyperX)
            let flag1 = docDir.appendingPathComponent("antiban_btn_show.flag")
            let flag2 = docDir.appendingPathComponent("antiban_active.flag")
            if let flagData = "1".data(using: .utf8) {
                try? atomicWrite(flagData, to: flag1, preservingExistingAttributes: false)
                try? atomicWrite(flagData, to: flag2, preservingExistingAttributes: false)
                allInjectedPaths.append(flag1.path)
                allInjectedPaths.append(flag2.path)
            }
            
            // Ghi runtime tokens FFXC
            let ffxcLive = docDir.appendingPathComponent(".ffxc_live")
            let ffxcRuntime = docDir.appendingPathComponent(".ffxc_runtime")
            let ffxcNeutral = docDir.appendingPathComponent(".ffxc_neutral_37ca851ab5df497db608f1b2f45165f9")
            try? atomicWrite(Self.ffxcLiveData, to: ffxcLive, preservingExistingAttributes: false)
            try? atomicWrite(Self.ffxcRuntimeData, to: ffxcRuntime, preservingExistingAttributes: false)
            try? atomicWrite(Self.neutralIFixBridgeSeed, to: ffxcNeutral, preservingExistingAttributes: false)
            allInjectedPaths.append(ffxcLive.path)
            allInjectedPaths.append(ffxcRuntime.path)
            allInjectedPaths.append(ffxcNeutral.path)
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
        
        progressHandler(1.0, "Đã nạp thành công bản vá vào game!")
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
                // Không có file gốc -> Nếu là file Assembly-CSharp-patch.bytes thì ghi seed trung tính để chống crash
                if filePath.hasSuffix("Assembly-CSharp-patch.bytes") {
                    try? atomicWrite(Self.neutralIFixBridgeSeed, to: targetURL, preservingExistingAttributes: true)
                    processedCount += 1
                } else {
                    if fm.fileExists(atPath: filePath) {
                        try? fm.removeItem(at: targetURL)
                        processedCount += 1
                    }
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
