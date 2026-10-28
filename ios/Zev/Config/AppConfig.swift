import Foundation

// MARK: - AppConfig
// Cấu hình API và thông tin app
// Để thay đổi server: chỉ cần đổi `baseURL` — không cần sửa code khác.

enum AppConfig {
    
    // ─── Server Configuration ──────────────────────────────────────────
    /// Mặc định: https://crackbomaydihihi.sbs
    /// Hệ thống hỗ trợ thay đổi domain qua UserDefaults hoặc cấu hình trực tiếp trong app
    static let defaultBaseURL: String = "https://crackbomaydihihi.sbs"
    
    static var baseURL: String {
        get {
            UserDefaults.standard.string(forKey: "zev.custom_base_url") ?? defaultBaseURL
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "zev.custom_base_url")
        }
    }
    
    /// Reset về domain mặc định
    static func resetBaseURL() {
        UserDefaults.standard.removeObject(forKey: "zev.custom_base_url")
    }
    
    /// API version prefix
    static let apiVersion: String = "v1"
    
    /// Full API base path
    static var apiBaseURL: String { "\(baseURL)/api/\(apiVersion)" }
    
    // ─── App Information ───────────────────────────────────────────────
    static let appName: String      = "Zev"
    static let appLogoURL: String   = "https://files.catbox.moe/kony5d.png"
    static let appVersion: String   = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    static let buildNumber: String  = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    // ─── API Endpoints ─────────────────────────────────────────────────
    enum Endpoints {
        static let verifyKey         = "/auth/verify"
        static let refreshKey        = "/auth/refresh"
        static let appConfig         = "/app/config"
        static let appVersion        = "/app/version"
        static let games             = "/games"
        static func gameCategories(_ id: Int) -> String { "/games/\(id)/categories" }
        static func gameFeatures(_ id: Int) -> String   { "/games/\(id)/features" }
        static func feature(_ id: Int) -> String        { "/features/\(id)" }
        static func fileMetadata(_ id: Int) -> String   { "/files/\(id)/metadata" }
        static func requestDownload(_ id: Int) -> String{ "/files/\(id)/request-download" }
        static let logError          = "/log/error"
    }
    
    // ─── Request Configuration ─────────────────────────────────────────
    static let requestTimeoutSeconds: Double = 30
    static let maxRetryAttempts: Int         = 3
    
    // ─── Keychain Keys ─────────────────────────────────────────────────
    enum KeychainKeys {
        static let activationKey    = "zev.activation_key"
        static let deviceIdentifier = "zev.device_id"
        static let keyExpiry        = "zev.key_expiry"
        static let keyStatus        = "zev.key_status"
    }
    
    // ─── UserDefaults Keys ─────────────────────────────────────────────
    enum UserDefaultsKeys {
        static let onboardingComplete   = "zev.onboarding_complete"
        static let selectedLanguage     = "zev.language"
        static let termsAccepted        = "zev.terms_accepted"
        static let lastConfigFetch      = "zev.last_config_fetch"
        static let cachedAppConfig      = "zev.cached_app_config"
    }
    
    // ─── Cache TTL ─────────────────────────────────────────────────────
    static let appConfigCacheTTL: TimeInterval = 300  // 5 phút
    
    // ─── Support ───────────────────────────────────────────────────────
    static let supportZalo: String = "0365829172"
    
    // ─── Games ─────────────────────────────────────────────────────────
    // Bundle IDs dùng để check URL scheme (canOpenURL) — không phải check bundle ID trực tiếp
    enum GameURLSchemes {
        static let freeFireTH  = "freefireth://"    // Scheme thực tế cần xác minh
        static let freeFireMAX = "freefiremax://"   // Scheme thực tế cần xác minh
    }
}
