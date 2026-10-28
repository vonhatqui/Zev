import Foundation
import UIKit

// MARK: - GamePatchService
// Cơ chế áp dụng Patch từ 3105-2.0 cho game Free Fire Thường & MAX
// Hỗ trợ nạp file .3105, file .bytes (Assembly-CSharp), localConfig.json, cache file và cấu hình sing-box

enum PatchError: LocalizedError {
    case gameContainerNotFound(String)
    case fileDownloadFailed(String)
    case unsupportedFormat(String)
    case permissionDenied(String)
    case applyFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .gameContainerNotFound(let bundleId):
            return "Không tìm thấy thư mục lưu trữ của game (\(bundleId)). Vui lòng đảm bảo game đã được mở ít nhất một lần."
        case .fileDownloadFailed(let reason):
            return "Tải file từ máy chủ thất bại: \(reason)"
        case .unsupportedFormat(let ext):
            return "Định dạng file không được hỗ trợ: .\(ext)"
        case .permissionDenied(let path):
            return "Không đủ quyền truy cập filesystem tại: \(path). Yêu cầu chứng chỉ Enterprise hoặc môi trường có quyền truy cập container."
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
        
        progressHandler(0.6, "Đang giải nén & kiểm tra container...")
        
        let targetBundleId = game.bundleId
        let originalFilename = feature.fileName ?? "patch_file"
        let fileExt = (originalFilename as NSString).pathExtension.lowercased()
        
        // Xử lý đặc biệt cho cấu hình Antiban (sing-box)
        if feature.targetPath == "sing-box" || feature.slug.contains("singbox") || feature.slug.contains("antiban") {
            try handleSingboxConfig(tempFileURL: tempLocalURL, filename: originalFilename)
            progressHandler(1.0, "Đã lưu cấu hình Antiban thành công!")
            return
        }
        
        // 3. Xác định đường dẫn Data Container của game
        let containerPath = GameDetectionService.shared.resolveAppContainer(bundleId: targetBundleId)
        
        // Đường dẫn fallback (Documents trong sandbox app để sao lưu/xuất file nếu không truy cập được trực tiếp)
        let documentsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let appPatchesDir = documentsDir.appendingPathComponent("AppliedPatches/\(targetBundleId)", isDirectory: true)
        try? fm.createDirectory(at: appPatchesDir, withIntermediateDirectories: true)
        
        progressHandler(0.8, "Đang ghi đè file vào game...")
        
        if let liveContainer = containerPath {
            // Có quyền truy cập data container của game
            let destinationSubdir = feature.targetPath ?? "Documents/"
            let destFolderURL = URL(fileURLWithPath: liveContainer).appendingPathComponent(destinationSubdir)
            try? fm.createDirectory(at: destFolderURL, withIntermediateDirectories: true)
            
            // Sao lưu file cũ nếu có
            let targetDestFile = destFolderURL.appendingPathComponent(originalFilename)
            if fm.fileExists(atPath: targetDestFile.path) {
                let backupDir = URL(fileURLWithPath: liveContainer).appendingPathComponent("Documents/Zev_Backups/\(Date().timeIntervalSince1970)")
                try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
                let backupDest = backupDir.appendingPathComponent(originalFilename)
                try? fm.copyItem(at: targetDestFile, to: backupDest)
                try? fm.removeItem(at: targetDestFile)
            }
            
            // Sao chép file mới vào
            try fm.copyItem(at: tempLocalURL, to: targetDestFile)
            progressHandler(1.0, "Đã nạp trực tiếp vào container game thành công!")
        } else {
            // Fallback lưu vào thư mục workspace Zev để chia sẻ hoặc nạp qua TrollStore / Filza
            let exportDest = appPatchesDir.appendingPathComponent(originalFilename)
            try? fm.removeItem(at: exportDest)
            try fm.copyItem(at: tempLocalURL, to: exportDest)
            progressHandler(1.0, "Đã lưu bản vá vào Documents/AppliedPatches thành công!")
        }
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
