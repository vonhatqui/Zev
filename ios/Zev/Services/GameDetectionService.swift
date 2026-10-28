import Foundation
import UIKit

// MARK: - GameDetectionService
// Kiểm tra trạng thái cài đặt của Free Fire Thường và Free Fire MAX trên máy

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
    
    /// Kiểm tra ứng dụng có cài đặt trên máy hay không
    func checkInstallation(bundleId: String) -> GameInstallState {
        // 1. Kiểm tra chính xác nhất qua URL Scheme đã đăng ký trong Info.plist (LSApplicationQueriesSchemes)
        let scheme: String?
        if bundleId == "com.dts.freefireth" {
            scheme = "freefireth"
        } else if bundleId == "com.dts.freefiremax" {
            scheme = "freefiremax"
        } else {
            scheme = nil
        }
        
        if let schemeStr = scheme, let url = URL(string: "\(schemeStr)://") {
            var canOpen = false
            if Thread.isMainThread {
                canOpen = UIApplication.shared.canOpenURL(url)
            } else {
                DispatchQueue.main.sync {
                    canOpen = UIApplication.shared.canOpenURL(url)
                }
            }
            if canOpen {
                return .installed
            }
        }
        
        // 2. Thử qua Private API an toàn trong Objective-C bridge (LSApplicationWorkspace / LSApplicationProxy)
        if MCMAppIsInstalled(bundleId as NSString) {
            return .installed
        }
        
        // 3. Quét kiểm tra Bundle .app thực tế trên ổ đĩa
        if appBundleExistsOnDisk(bundleId: bundleId) {
            return .installed
        }
        
        return .notInstalled
    }
    
    /// Kiểm tra xem Application Bundle (.app) thực tế có tồn tại trên đĩa không
    private func appBundleExistsOnDisk(bundleId: String) -> Bool {
        let roots = [
            "/private/var/containers/Bundle/Application",
            "/var/containers/Bundle/Application",
            "/Applications"
        ]
        let fm = FileManager.default
        for root in roots {
            guard let dirs = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for dir in dirs {
                let subPath = "\(root)/\(dir)"
                if let subDirs = try? fm.contentsOfDirectory(atPath: subPath) {
                    for item in subDirs where item.hasSuffix(".app") {
                        let appPath = "\(subPath)/\(item)"
                        let infoPlistPath = "\(appPath)/Info.plist"
                        if let dict = NSDictionary(contentsOfFile: infoPlistPath),
                           let id = dict["CFBundleIdentifier"] as? String,
                           id == bundleId {
                            return true
                        }
                    }
                } else if dir.hasSuffix(".app") {
                    let infoPlistPath = "\(subPath)/Info.plist"
                    if let dict = NSDictionary(contentsOfFile: infoPlistPath),
                       let id = dict["CFBundleIdentifier"] as? String,
                       id == bundleId {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    /// Tìm đường dẫn Data Container của Bundle ID và kích hoạt quyền truy cập sandbox
    func resolveAppContainer(bundleId: String) -> String? {
        // Chỉ phân giải container nếu game thực sự ĐÃ CÀI ĐẶT trên thiết bị
        guard checkInstallation(bundleId: bundleId).isInstalled else {
            return nil
        }
        
        // 1. MobileContainerManager bridge (MobileHouseArrest - Class 2 AppData Container)
        var lookupError: NSString?
        if let path = MCMActivateContainerPath(2, bundleId, false, &lookupError), !path.isEmpty {
            #if DEBUG
            print("[GameDetectionService] Resolved & activated container for \(bundleId): \(path)")
            #endif
            return path
        }
        
        #if DEBUG
        if let err = lookupError {
            print("[GameDetectionService] MCM lookup error for \(bundleId): \(err)")
        }
        #endif
        
        // 2. Thử qua Private API LSApplicationProxy (TrollStore / Enterprise)
        if let proxyClass = NSClassFromString("LSApplicationProxy") as? NSObject.Type {
            let sel = NSSelectorFromString("applicationProxyForIdentifier:")
            if proxyClass.responds(to: sel) {
                if let proxy = proxyClass.perform(sel, with: bundleId)?.takeUnretainedValue() {
                    let containerSel = NSSelectorFromString("containerURL")
                    if proxy.responds(to: containerSel), let url = proxy.perform(containerSel)?.takeUnretainedValue() as? URL {
                        if !url.path.isEmpty && FileManager.default.fileExists(atPath: url.path) {
                            return url.path
                        }
                    }
                }
            }
        }
        
        // 3. Quét trực tiếp /var/mobile/Containers/Data/Application
        let appDataRoots = ["/private/var/mobile/Containers/Data/Application", "/var/mobile/Containers/Data/Application"]
        let fm = FileManager.default
        
        for appDataRoot in appDataRoots {
            if let dirs = try? fm.contentsOfDirectory(atPath: appDataRoot) {
                for dir in dirs {
                    let containerPath = "\(appDataRoot)/\(dir)"
                    let metadataPath = "\(containerPath)/.com.apple.mobile_container_manager.metadata.plist"
                    
                    if fm.fileExists(atPath: metadataPath),
                       let data = try? Data(contentsOf: URL(fileURLWithPath: metadataPath)),
                       let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                       let identifier = plist["MCMMetadataIdentifier"] as? String,
                       identifier == bundleId {
                        return containerPath
                    }
                }
            }
        }
        
        return nil
    }
}
