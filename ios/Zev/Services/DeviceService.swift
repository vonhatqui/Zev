import Foundation
import UIKit

// MARK: - DeviceService
// Lấy thông tin thiết bị từ API hệ thống iOS

final class DeviceService {
    
    static let shared = DeviceService()
    private init() {}
    
    // MARK: - Device Identifier
    // Dùng identifierForVendor (IDFV) — stable trong app lifecycle
    // Lưu vào Keychain để bền vững hơn giữa các lần cài lại
    
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
    
    // MARK: - Device Model
    // iOS không cung cấp tên thương mại qua public API
    // Chỉ có model identifier (e.g. "iPhone16,2")
    // Tra bảng để lấy tên thương mại nếu có
    
    var deviceModelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
    
    /// Tên thương mại nếu có trong lookup table, ngược lại trả model identifier
    var deviceDisplayName: String {
        let identifier = deviceModelIdentifier
        return DeviceModelLookup.displayName(for: identifier) ?? identifier
    }
    
    // MARK: - App Version
    
    var appVersion: String {
        AppConfig.appVersion
    }
    
    // MARK: - Device Name (user-defined, not device model)
    // Đây là tên người dùng đặt cho thiết bị, không phải model
    var deviceName: String {
        UIDevice.current.name
    }
    
    // MARK: - System Info Summary
    
    var systemInfoSummary: String {
        "iOS \(iosVersion) · \(deviceDisplayName)"
    }
}

// MARK: - Device Model Lookup
// Bảng tra cứu tên thương mại từ model identifier
// Nguồn: https://www.theiphonewiki.com/wiki/Models
// Cập nhật khi Apple ra thiết bị mới

enum DeviceModelLookup {
    
    static func displayName(for identifier: String) -> String? {
        return table[identifier]
    }
    
    // Chỉ bao gồm các model phổ biến — cập nhật thêm khi cần
    private static let table: [String: String] = [
        // iPhone 16 series
        "iPhone17,1": "iPhone 16 Pro Max",
        "iPhone17,2": "iPhone 16 Pro",
        "iPhone17,3": "iPhone 16 Plus",
        "iPhone17,4": "iPhone 16",
        // iPhone 15 series
        "iPhone16,1": "iPhone 15",
        "iPhone16,2": "iPhone 15 Plus",
        "iPhone16,3": "iPhone 15 Pro",
        "iPhone16,4": "iPhone 15 Pro Max",
        // iPhone 14 series
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 14",
        "iPhone15,5": "iPhone 14 Plus",
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
        // iPhone SE
        "iPhone12,8": "iPhone SE (2nd gen)",
        "iPhone14,6": "iPhone SE (3rd gen)",
        // Simulator
        "x86_64":     "Simulator (x86_64)",
        "arm64":      "Simulator (arm64)",
    ]
}
