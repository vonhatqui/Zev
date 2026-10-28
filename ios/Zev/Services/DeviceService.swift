import Foundation
import UIKit

// MARK: - DeviceService
// Lấy thông tin thiết bị từ API hệ thống iOS và tra bảng tên thương mại chính xác

final class DeviceService {
    
    static let shared = DeviceService()
    private init() {}
    
    // MARK: - Device Identifier (HWID)
    
    var deviceIdentifier: String {
        let keychainKey = AppConfig.KeychainKeys.deviceIdentifier
        
        // Kiểm tra đã lưu trong Keychain chưa
        if let saved = KeychainService.shared.load(forKey: keychainKey), !saved.isEmpty {
            return saved
        }
        
        // Lấy IDFV từ hệ thống
        let idfv = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        
        // Lưu vào Keychain
        KeychainService.shared.save(idfv, forKey: keychainKey)
        return idfv
    }
    
    // MARK: - iOS Version
    
    var iosVersion: String {
        UIDevice.current.systemVersion
    }
    
    // MARK: - iOS Build Number
    
    var iosBuildNumber: String {
        var size: Int = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.osversion", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }
    
    // MARK: - Device Model Identifier (e.g. "iPhone16,2")
    
    var deviceModelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
    
    /// Tên thương mại chính xác (ví dụ "iPhone 15 Pro Max", "iPad Pro 11-inch (4th gen)")
    var deviceCommercialName: String {
        let identifier = deviceModelIdentifier
        return DeviceModelLookup.displayName(for: identifier) ?? identifier
    }
    
    var deviceDisplayName: String {
        deviceCommercialName
    }
    
    // MARK: - App Version
    
    var appVersion: String {
        AppConfig.appVersion
    }
    
    // MARK: - System Info Summary
    
    var systemInfoSummary: String {
        "\(deviceCommercialName) · iOS \(iosVersion)"
    }
}

// MARK: - Device Model Lookup
// Bảng tra cứu tên thương mại chính xác từ model identifier (iPhone & iPad)

enum DeviceModelLookup {
    
    static func displayName(for identifier: String) -> String? {
        if let exact = table[identifier] {
            return exact
        }
        
        // Fallback nhận dạng mẫu
        if identifier.hasPrefix("iPhone") {
            return "Apple iPhone (\(identifier))"
        } else if identifier.hasPrefix("iPad") {
            return "Apple iPad (\(identifier))"
        }
        
        return nil
    }
    
    private static let table: [String: String] = [
        // iPhone 16 series
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        
        // iPhone 15 series
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        
        // iPhone 14 series
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        
        // iPhone 13 series
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        
        // iPhone 12 series
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        
        // iPhone 11 series
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        
        // iPhone XS / XR / X
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max",
        "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR",
        "iPhone10,3": "iPhone X",
        "iPhone10,6": "iPhone X",
        
        // iPhone 8 / 7 / 6s
        "iPhone10,1": "iPhone 8",
        "iPhone10,4": "iPhone 8",
        "iPhone10,2": "iPhone 8 Plus",
        "iPhone10,5": "iPhone 8 Plus",
        "iPhone9,1":  "iPhone 7",
        "iPhone9,3":  "iPhone 7",
        "iPhone9,2":  "iPhone 7 Plus",
        "iPhone9,4":  "iPhone 7 Plus",
        "iPhone8,1":  "iPhone 6s",
        "iPhone8,2":  "iPhone 6s Plus",
        
        // iPhone SE
        "iPhone8,4":  "iPhone SE (1st gen)",
        "iPhone12,8": "iPhone SE (2nd gen)",
        "iPhone14,6": "iPhone SE (3rd gen)",
        
        // iPad Pro M4 (2024)
        "iPad16,3": "iPad Pro 11-inch (M4)",
        "iPad16,4": "iPad Pro 11-inch (M4)",
        "iPad16,5": "iPad Pro 13-inch (M4)",
        "iPad16,6": "iPad Pro 13-inch (M4)",
        
        // iPad Pro 12.9-inch
        "iPad14,5": "iPad Pro 12.9-inch (6th gen)",
        "iPad14,6": "iPad Pro 12.9-inch (6th gen)",
        "iPad13,8": "iPad Pro 12.9-inch (5th gen)",
        "iPad13,9": "iPad Pro 12.9-inch (5th gen)",
        "iPad13,10": "iPad Pro 12.9-inch (5th gen)",
        "iPad13,11": "iPad Pro 12.9-inch (5th gen)",
        "iPad8,11": "iPad Pro 12.9-inch (4th gen)",
        "iPad8,12": "iPad Pro 12.9-inch (4th gen)",
        "iPad8,5":  "iPad Pro 12.9-inch (3rd gen)",
        "iPad8,6":  "iPad Pro 12.9-inch (3rd gen)",
        "iPad8,7":  "iPad Pro 12.9-inch (3rd gen)",
        "iPad8,8":  "iPad Pro 12.9-inch (3rd gen)",
        
        // iPad Pro 11-inch
        "iPad14,3": "iPad Pro 11-inch (4th gen)",
        "iPad14,4": "iPad Pro 11-inch (4th gen)",
        "iPad13,4": "iPad Pro 11-inch (3rd gen)",
        "iPad13,5": "iPad Pro 11-inch (3rd gen)",
        "iPad13,6": "iPad Pro 11-inch (3rd gen)",
        "iPad13,7": "iPad Pro 11-inch (3rd gen)",
        "iPad8,9":  "iPad Pro 11-inch (2nd gen)",
        "iPad8,10": "iPad Pro 11-inch (2nd gen)",
        "iPad8,1":  "iPad Pro 11-inch (1st gen)",
        "iPad8,2":  "iPad Pro 11-inch (1st gen)",
        "iPad8,3":  "iPad Pro 11-inch (1st gen)",
        "iPad8,4":  "iPad Pro 11-inch (1st gen)",
        
        // iPad Air
        "iPad14,8": "iPad Air 11-inch (M2)",
        "iPad14,9": "iPad Air 11-inch (M2)",
        "iPad14,10": "iPad Air 13-inch (M2)",
        "iPad14,11": "iPad Air 13-inch (M2)",
        "iPad13,16": "iPad Air (5th gen)",
        "iPad13,17": "iPad Air (5th gen)",
        "iPad13,1":  "iPad Air (4th gen)",
        "iPad13,2":  "iPad Air (4th gen)",
        "iPad11,3":  "iPad Air (3rd gen)",
        "iPad11,4":  "iPad Air (3rd gen)",
        
        // iPad mini
        "iPad16,1": "iPad mini (A17 Pro)",
        "iPad16,2": "iPad mini (A17 Pro)",
        "iPad14,1": "iPad mini (6th gen)",
        "iPad14,2": "iPad mini (6th gen)",
        "iPad11,1": "iPad mini (5th gen)",
        "iPad11,2": "iPad mini (5th gen)",
        
        // iPad (standard)
        "iPad13,18": "iPad (10th gen)",
        "iPad13,19": "iPad (10th gen)",
        "iPad12,1":  "iPad (9th gen)",
        "iPad12,2":  "iPad (9th gen)",
        "iPad11,6":  "iPad (8th gen)",
        "iPad11,7":  "iPad (8th gen)",
        "iPad7,11":  "iPad (7th gen)",
        "iPad7,12":  "iPad (7th gen)",
        
        // Simulator
        "x86_64": "Simulator (Mac x86_64)",
        "arm64":  "Simulator (Apple Silicon)",
    ]
}
