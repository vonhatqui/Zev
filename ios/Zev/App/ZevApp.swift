import SwiftUI
import UserNotifications

@main
struct ZevApp: App {
    
    @StateObject private var appState = AppStateManager.shared
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        Group {
            if appState.isLoading {
                SplashView()
            } else if !appState.onboardingComplete {
                OnboardingView()
            } else if !appState.isActivated {
                KeyActivationView()
            } else if appState.selectedGame == nil {
                GameSelectionView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.onboardingComplete)
        .animation(.easeInOut(duration: 0.3), value: appState.isActivated)
        .animation(.easeInOut(duration: 0.3), value: appState.selectedGame?.id)
        .task {
            await appState.initialize()
        }
    }
}

// MARK: - AppStateManager

@MainActor
final class AppStateManager: ObservableObject {
    
    static let shared = AppStateManager()
    
    @Published var isLoading: Bool          = true
    @Published var onboardingComplete: Bool = false
    @Published var isActivated: Bool        = false
    @Published var activationKey: String    = ""
    @Published var keyInfo: KeyInfo?
    @Published var deviceInfo: DeviceInfo?
    @Published var selectedGame: Game?      = nil
    @Published var appConfig: AppConfiguration?
    @Published var maintenanceMode: Bool    = false
    @Published var maintenanceMessage: String = ""
    
    private let defaults = UserDefaults.standard
    private let keychain = KeychainService.shared
    
    private init() {}
    
    func initialize() async {
        // Kiểm tra trạng thái onboarding
        onboardingComplete = defaults.bool(forKey: AppConfig.UserDefaultsKeys.onboardingComplete)
        
        // Kiểm tra key đã lưu
        if let savedKey = keychain.load(forKey: AppConfig.KeychainKeys.activationKey), !savedKey.isEmpty {
            activationKey = savedKey
            
            // Validate key với server
            await refreshKeyStatus()
        }
        
        // Tải cấu hình app
        await fetchAppConfig()
        
        isLoading = false
    }
    
    func completeOnboarding() {
        defaults.set(true, forKey: AppConfig.UserDefaultsKeys.onboardingComplete)
        onboardingComplete = true
    }
    
    func activateKey(_ key: String, result: ActivationResult) {
        activationKey = key
        keyInfo       = result.key
        deviceInfo    = result.device
        isActivated   = true
        
        // Lưu vào Keychain
        keychain.save(key, forKey: AppConfig.KeychainKeys.activationKey)
        keychain.save(result.key.status, forKey: AppConfig.KeychainKeys.keyStatus)
        if let expiry = result.key.expiresAt {
            keychain.save(expiry, forKey: AppConfig.KeychainKeys.keyExpiry)
        }
    }
    
    func selectGame(_ game: Game) {
        selectedGame = game
    }
    
    func switchGame() {
        selectedGame = nil
    }
    
    func logout() {
        isActivated = false
        activationKey = ""
        keyInfo     = nil
        deviceInfo  = nil
        selectedGame = nil
        keychain.clearAll()
    }
    
    func refreshKeyStatus() async {
        guard !activationKey.isEmpty else { return }
        
        do {
            let response = try await APIService.shared.refreshKeyStatus()
            if let data = response.data {
                keyInfo    = data.key
                isActivated = data.key.status == "active" && !data.key.isExpired
                
                if !isActivated {
                    // Key đã hết hạn hoặc bị thu hồi
                    keychain.clearAll()
                    activationKey = ""
                }
            }
        } catch {
            // Network error — vẫn cho dùng nếu đang offline
            // Chỉ logout khi server trả 401/403
            if case .unauthorized = error as? APIError {
                logout()
            } else if case .serverError(let code, _) = error as? APIError, code == 403 {
                logout()
            } else {
                // Dùng cached status
                isActivated = !activationKey.isEmpty
            }
        }
    }
    
    private func fetchAppConfig() async {
        // Dùng cache nếu còn mới
        let lastFetch = defaults.double(forKey: AppConfig.UserDefaultsKeys.lastConfigFetch)
        if Date().timeIntervalSince1970 - lastFetch < AppConfig.appConfigCacheTTL {
            if let cached = defaults.data(forKey: AppConfig.UserDefaultsKeys.cachedAppConfig),
               let config = try? JSONDecoder().decode(AppConfiguration.self, from: cached) {
                appConfig = config
                return
            }
        }
        
        do {
            let config = try await APIService.shared.fetchAppConfig()
            appConfig  = config
            
            // Kiểm tra maintenance
            maintenanceMode = config.config["maintenance_mode"] == "1"
            let lang = UserDefaults.standard.string(forKey: AppConfig.UserDefaultsKeys.selectedLanguage) ?? "vi"
            maintenanceMessage = config.config[lang == "vi" ? "maintenance_message_vi" : "maintenance_message_en"] ?? ""
            
            // Cache
            if let encoded = try? JSONEncoder().encode(config) {
                defaults.set(encoded, forKey: AppConfig.UserDefaultsKeys.cachedAppConfig)
                defaults.set(Date().timeIntervalSince1970, forKey: AppConfig.UserDefaultsKeys.lastConfigFetch)
            }
        } catch {
            // Tiếp tục với cached hoặc không có config
        }
    }
}
