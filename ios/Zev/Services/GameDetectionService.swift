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
        // 1. Thử qua Private API LSApplicationProxy (nếu được ký Enterprise/TrollStore)
        if let proxyClass = NSClassFromString("LSApplicationProxy") as? NSObject.Type {
            let sel = NSSelectorFromString("applicationProxyForIdentifier:")
            if proxyClass.responds(to: sel) {
                if let proxy = proxyClass.perform(sel, with: bundleId)?.takeUnretainedValue() {
                    let installedSel = NSSelectorFromString("isInstalled")
                    if proxy.responds(to: installedSel) {
                        let isInstalled = proxy.perform(installedSel) != nil
                        if isInstalled {
                            return .installed
                        }
                    }
                    // Nếu lấy được containerURL -> chắc chắn đã cài
                    let containerSel = NSSelectorFromString("containerURL")
                    if proxy.responds(to: containerSel), let url = proxy.perform(containerSel)?.takeUnretainedValue() as? URL {
                        if !url.path.isEmpty {
                            return .installed
                        }
                    }
                }
            }
        }
        
        // 2. Thử qua URL scheme tương ứng
        let scheme: String?
        if bundleId == "com.dts.freefireth" {
            scheme = "freefireth://"
        } else if bundleId == "com.dts.freefiremax" {
            scheme = "freefiremax://"
        } else {
            scheme = nil
        }
        
        if let schemeStr = scheme, let url = URL(string: schemeStr) {
            if UIApplication.shared.canOpenURL(url) {
                return .installed
            }
        }
        
        // 3. Thử tìm kiếm data container trong /var/mobile/Containers/Data/Application
        if let containerPath = resolveAppContainer(bundleId: bundleId), !containerPath.isEmpty {
            return .installed
        }
        
        return .notInstalled
    }
    
    /// Tìm đường dẫn Data Container của Bundle ID và kích hoạt quyền truy cập sandbox
    func resolveAppContainer(bundleId: String) -> String? {
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
