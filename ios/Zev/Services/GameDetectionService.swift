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
        // 1. Thử qua MobileContainerManager (libsystem_containermanager.dylib) với danh tính MobileHouseArrest
        if let mcmPath = resolveViaMobileContainerManager(bundleId: bundleId) {
            return mcmPath
        }
        
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
        let appDataRoots = ["/var/mobile/Containers/Data/Application", "/private/var/mobile/Containers/Data/Application"]
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
    
    // MARK: - MobileContainerManager (libsystem_containermanager.dylib)
    
    private func resolveViaMobileContainerManager(bundleId: String) -> String? {
        guard let handle = dlopen("/usr/lib/system/libsystem_containermanager.dylib", RTLD_NOW | RTLD_LOCAL) else {
            return nil
        }
        defer { dlclose(handle) }
        
        typealias QueryCreate = @convention(c) () -> UnsafeMutableRawPointer?
        typealias QuerySetClass = @convention(c) (UnsafeMutableRawPointer?, UInt64) -> Void
        typealias QuerySetIdentifiers = @convention(c) (UnsafeMutableRawPointer?, AnyObject) -> Void
        typealias QuerySetFlags = @convention(c) (UnsafeMutableRawPointer?, UInt64) -> Void
        typealias QueryGetSingle = @convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?
        typealias QueryFree = @convention(c) (UnsafeMutableRawPointer?) -> Void
        typealias ObjectGetPath = @convention(c) (UnsafeMutableRawPointer?) -> UnsafePointer<CChar>?
        typealias ObjectCopy = @convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?
        typealias ObjectActivate = @convention(c) (UnsafeMutableRawPointer?, Bool) -> Bool
        typealias ObjectFree = @convention(c) (UnsafeMutableRawPointer?) -> Void
        
        guard let queryCreateSym = dlsym(handle, "container_query_create"),
              let querySetClassSym = dlsym(handle, "container_query_set_class"),
              let querySetIdentifiersSym = dlsym(handle, "container_query_set_identifiers"),
              let querySetFlagsSym = dlsym(handle, "container_query_operation_set_flags"),
              let queryGetSingleSym = dlsym(handle, "container_query_get_single_result"),
              let queryFreeSym = dlsym(handle, "container_query_free"),
              let objectGetPathSym = dlsym(handle, "container_object_get_path") else {
            return nil
        }
        
        let queryCreate = unsafeBitCast(queryCreateSym, to: QueryCreate.self)
        let querySetClass = unsafeBitCast(querySetClassSym, to: QuerySetClass.self)
        let querySetIdentifiers = unsafeBitCast(querySetIdentifiersSym, to: QuerySetIdentifiers.self)
        let querySetFlags = unsafeBitCast(querySetFlagsSym, to: QuerySetFlags.self)
        let queryGetSingle = unsafeBitCast(queryGetSingleSym, to: QueryGetSingle.self)
        let queryFree = unsafeBitCast(queryFreeSym, to: QueryFree.self)
        let objectGetPath = unsafeBitCast(objectGetPathSym, to: ObjectGetPath.self)
        
        guard let query = queryCreate() else { return nil }
        defer { queryFree(query) }
        
        querySetClass(query, 1) // 1 = App Data Container
        querySetIdentifiers(query, bundleId as NSString)
        querySetFlags(query, 0x900000000)
        
        guard let result = queryGetSingle(query) else { return nil }
        
        // Kích hoạt sandbox extension nếu khả dụng
        if let objectCopySym = dlsym(handle, "container_object_copy"),
           let objectActivateSym = dlsym(handle, "container_object_sandbox_extension_activate"),
           let objectFreeSym = dlsym(handle, "container_object_free") {
            let objectCopy = unsafeBitCast(objectCopySym, to: ObjectCopy.self)
            let objectActivate = unsafeBitCast(objectActivateSym, to: ObjectActivate.self)
            let objectFree = unsafeBitCast(objectFreeSym, to: ObjectFree.self)
            
            if let activation = objectCopy(result) {
                _ = objectActivate(activation, false)
                objectFree(activation)
            }
        }
        
        guard let rawPath = objectGetPath(result) else { return nil }
        var path = String(cString: rawPath)
        if path.hasPrefix("/var/") {
            path = "/private" + path
        }
        return path.isEmpty ? nil : path
    }
}
