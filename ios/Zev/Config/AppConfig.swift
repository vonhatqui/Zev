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
    static var appLogoURL: String   { "\(baseURL)/admin/assets/images/logo.png" }
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
        static func activePatch(_ id: Int) -> String    { "/games/\(id)/patch" }
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
    
    // ─── Games & Categories ───────────────────────────────────────────
    enum CategoryLogos {
        static let menuProject = "https://files.catbox.moe/wetz7r.png"
        static let aimCache    = "https://files.catbox.moe/z7c8o6.png"
        static let modskinFFTH = "https://files.catbox.moe/dvyw27.png"
    }
    
    enum GameLogos {
        // Logo chính thức Free Fire Thường (https://ibb.co/xSHNXJF9) & MAX (https://ibb.co/j9R2HrQd)
        static let freeFireTH  = "https://i.ibb.co/7J4qj2kM/IMG-4819.webp"
        static let freeFireMAX = "https://i.ibb.co/spHGtVNh/IMG-4818.png"
    }
    
    static let singboxAppStoreURL = "https://apps.apple.com/app/sing-box/id6451272673"
    
    enum GameURLSchemes {
        static let freeFireTH  = "freefireth://"
        static let freeFireMAX = "freefiremax://"
        static let singbox     = "sing-box://"
    }
}
