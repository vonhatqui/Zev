import Foundation
import UIKit
import Darwin

// MARK: - GameDetectionService
// Kiểm tra trạng thái cài đặt chuẩn 3105: Chỉ báo "Sẵn sàng" khi container hợp lệ thực tế tồn tại

enum GameInstallState {
    case installed
    case notInstalled
    
    var displayText: String {
        switch self {
        case .installed:    return "Sẵn sàng"
        case .notInstalled: return "Chưa Cài Đặt"
        }
    }
    
    var isInstalled: Bool {
        self == .installed
    }
}

final class GameDetectionService {
    
    static let shared = GameDetectionService()
    private init() {}
    
    // MARK: - Path Normalization & Validation (3105 Parity)
    
    /// Chuẩn hóa đường dẫn canonical (/private/var/...)
    func canonicalPath(_ path: String) -> String {
        var clean = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean == "/var" || clean.hasPrefix("/var/") {
            clean = "/private" + clean
        }
        if clean.hasSuffix("/") {
            clean = String(clean.dropLast())
        }
        return clean
    }
    
    /// Kiểm tra đường dẫn có phải là App Data Container hợp lệ (/private/var/mobile/Containers/Data/Application/<UUID>)
    func isApplicationContainerPath(_ path: String) -> Bool {
        let clean = canonicalPath(path)
        let appDataRoot = "/private/var/mobile/Containers/Data/Application"
        guard clean.hasPrefix(appDataRoot + "/") else { return false }
        let last = (clean as NSString).lastPathComponent
        return UUID(uuidString: last) != nil
    }
    
    // MARK: - Installation Detection
    
    /// Kiểm tra ứng dụng có cài đặt trên máy hay không
    /// Bắt buộc phải tìm thấy Data Container hợp lệ của game để tránh báo ảo "Sẵn sàng"
    func checkInstallation(bundleId: String) -> GameInstallState {
        // 1. Kiểm tra container thực tế hợp lệ (tiêu chí chuẩn xác 100%)
        if let containerPath = resolveAppContainer(bundleId: bundleId),
           isApplicationContainerPath(containerPath) {
            return .installed
        }

        // 2. Thử qua Private API LSApplicationProxy (nếu cài qua TrollStore/Enterprise)
        if let proxyClass = NSClassFromString("LSApplicationProxy") as? NSObject.Type {
            let sel = NSSelectorFromString("applicationProxyForIdentifier:")
            if proxyClass.responds(to: sel) {
                if let proxy = proxyClass.perform(sel, with: bundleId)?.takeUnretainedValue() {
                    let installedSel = NSSelectorFromString("isInstalled")
                    if proxy.responds(to: installedSel) {
                        let isInstalled = proxy.perform(installedSel) != nil
                        if isInstalled {
                            let containerSel = NSSelectorFromString("containerURL")
                            if proxy.responds(to: containerSel),
                               let url = proxy.perform(containerSel)?.takeUnretainedValue() as? URL,
                               isApplicationContainerPath(url.path) {
                                return .installed
                            }
                        }
                    }
                }
            }
        }
        
        return .notInstalled
    }
    
    // MARK: - Container Resolution (MCM & Filesystem Walk)
    
    /// Tìm đường dẫn Data Container của Bundle ID và kích hoạt quyền truy cập sandbox
    func resolveAppContainer(bundleId: String) -> String? {
        // 1. MobileContainerManager bridge (MobileHouseArrest - Class 2 AppData Container)
        var lookupError: NSString?
        if let path = MCMActivateContainerPath(2, bundleId, false, &lookupError) {
            let canon = canonicalPath(path)
            if isApplicationContainerPath(canon) {
                #if DEBUG
                print("[GameDetectionService] Resolved & activated container for \(bundleId): \(canon)")
                #endif
                return canon
            }
        }
        
        // 2. Thử qua Private API LSApplicationProxy (TrollStore / Enterprise)
        if let proxyClass = NSClassFromString("LSApplicationProxy") as? NSObject.Type {
            let sel = NSSelectorFromString("applicationProxyForIdentifier:")
            if proxyClass.responds(to: sel) {
                if let proxy = proxyClass.perform(sel, with: bundleId)?.takeUnretainedValue() {
                    let containerSel = NSSelectorFromString("containerURL")
                    if proxy.responds(to: containerSel),
                       let url = proxy.perform(containerSel)?.takeUnretainedValue() as? URL {
                        let canon = canonicalPath(url.path)
                        if isApplicationContainerPath(canon) {
                            return canon
                        }
                    }
                }
            }
        }
        
        // 3. Quét trực tiếp /private/var/mobile/Containers/Data/Application bằng Metadata scan
        if let scanned = resolveByMetadataScan(bundleId: bundleId) {
            return scanned
        }
        
        return nil
    }
    
    /// Quét toàn bộ thư mục Applications và đọc file metadata plist để phân giải bundleId
    private func resolveByMetadataScan(bundleId: String) -> String? {
        let appDataRoots = [
            "/private/var/mobile/Containers/Data/Application",
            "/var/mobile/Containers/Data/Application"
        ]
        let fm = FileManager.default
        
        for appDataRoot in appDataRoots {
            var candidateDirs: [String] = []
            if let dirs = try? fm.contentsOfDirectory(atPath: appDataRoot) {
                candidateDirs = dirs
            } else if let dirPtr = opendir(appDataRoot) {
                defer { closedir(dirPtr) }
                while let entry = readdir(dirPtr) {
                    let name = withUnsafePointer(to: &entry.pointee.d_name) {
                        $0.withMemoryRebound(to: CChar.self, capacity: 256) {
                            String(cString: $0)
                        }
                    }
                    if !name.isEmpty && name != "." && name != ".." {
                        candidateDirs.append(name)
                    }
                }
            }
            
            for dir in candidateDirs {
                guard UUID(uuidString: dir) != nil else { continue }
                let containerPath = (appDataRoot as NSString).appendingPathComponent(dir)
                let metadataPath = (containerPath as NSString).appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
                
                var data: Data? = nil
                if let fd = fopen(metadataPath, "r") {
                    var buffer = [UInt8](repeating: 0, count: 65536)
                    var bytes: [UInt8] = []
                    while true {
                        let n = fread(&buffer, 1, buffer.count, fd)
                        if n <= 0 { break }
                        bytes.append(contentsOf: buffer[0..<n])
                    }
                    fclose(fd)
                    if !bytes.isEmpty { data = Data(bytes) }
                }
                if data == nil {
                    data = try? Data(contentsOf: URL(fileURLWithPath: metadataPath))
                }
                
                if let validData = data,
                   let plist = try? PropertyListSerialization.propertyList(from: validData, options: [], format: nil) as? [String: Any],
                   let identifier = plist["MCMMetadataIdentifier"] as? String,
                   identifier == bundleId {
                    let canonical = canonicalPath(containerPath)
                    if isApplicationContainerPath(canonical) {
                        return canonical
                    }
                }
            }
        }
        return nil
    }
}

