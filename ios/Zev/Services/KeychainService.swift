import Foundation
import Security

// MARK: - KeychainService
// Lưu trữ an toàn thông tin nhạy cảm (key, device ID)

final class KeychainService {
    
    static let shared = KeychainService()
    private init() {}
    
    // MARK: - Save
    
    @discardableResult
    func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // Xóa entry cũ trước
        delete(forKey: key)
        
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrAccount as String:      key,
            kSecAttrService as String:      "com.zev.app",
            kSecValueData as String:        data,
            kSecAttrAccessible as String:   kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Load
    
    func load(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrAccount as String:      key,
            kSecAttrService as String:      "com.zev.app",
            kSecMatchLimit as String:       kSecMatchLimitOne,
            kSecReturnData as String:       true,
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        
        return string
    }
    
    // MARK: - Delete
    
    @discardableResult
    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.zev.app",
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Clear All
    
    func clearAll() {
        let keys = [
            AppConfig.KeychainKeys.activationKey,
            AppConfig.KeychainKeys.deviceIdentifier,
            AppConfig.KeychainKeys.keyExpiry,
            AppConfig.KeychainKeys.keyStatus,
        ]
        keys.forEach { delete(forKey: $0) }
    }
}
