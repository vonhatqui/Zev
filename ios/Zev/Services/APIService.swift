import Foundation

// MARK: - APIError

enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decodingFailed(String)
    case serverError(Int, String)
    case networkError(String)
    case unauthorized
    case notFound
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:               return "URL không hợp lệ."
        case .noData:                   return "Không nhận được dữ liệu từ server."
        case .decodingFailed(let msg):  return "Lỗi xử lý dữ liệu: \(msg)"
        case .serverError(_, let msg):  return msg
        case .networkError(let msg):    return "Lỗi mạng: \(msg)"
        case .unauthorized:             return "Chưa xác thực. Vui lòng kích hoạt key."
        case .notFound:                 return "Không tìm thấy tài nguyên."
        case .rateLimited:              return "Quá nhiều yêu cầu. Vui lòng thử lại sau."
        }
    }
}

// MARK: - APIService

// MARK: - SSL Bypass Delegate (Hỗ trợ chứng chỉ cPanel tự ký / đang cấp)
final class SSLBypassDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }
        completionHandler(.performDefaultHandling, nil)
    }
}

final class APIService {
    
    static let shared = APIService()
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let sessionDelegate = SSLBypassDelegate()
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = AppConfig.requestTimeoutSeconds
        config.timeoutIntervalForResource = AppConfig.requestTimeoutSeconds * 2
        config.httpAdditionalHeaders = [
            "X-App-Version": AppConfig.appVersion,
            "Content-Type":  "application/json",
            "Accept":        "application/json",
        ]
        self.session = URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)
        self.decoder = JSONDecoder()
    }
    
    // MARK: - Generic Request
    
    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        
        let urlString = AppConfig.apiBaseURL + endpoint
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Auth headers
        if requiresAuth {
            let key      = KeychainService.shared.load(forKey: AppConfig.KeychainKeys.activationKey) ?? ""
            let deviceId = DeviceService.shared.deviceIdentifier
            request.setValue(key, forHTTPHeaderField: "X-API-Key")
            request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        }
        
        // Body
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        // Execute
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.noData
            }
            
            // Handle HTTP errors
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 401:
                throw APIError.unauthorized
            case 404:
                throw APIError.notFound
            case 429:
                throw APIError.rateLimited
            default:
                // Try to extract error message from response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    throw APIError.serverError(httpResponse.statusCode, message)
                }
                throw APIError.serverError(httpResponse.statusCode, "Lỗi server (\(httpResponse.statusCode)).")
            }
            
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingFailed(error.localizedDescription)
            }
            
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Verify Key
    
    func verifyKey(_ keyCode: String) async throws -> ActivationResult {
        let device = DeviceService.shared
        let body: [String: Any] = [
            "key":          keyCode,
            "device_id":    device.deviceIdentifier,
            "ios_version":  device.iosVersion,
            "device_model": device.deviceCommercialName,
            "app_version":  AppConfig.appVersion,
        ]
        
        let response: APIResponse<ActivationResult> = try await request(
            endpoint: AppConfig.Endpoints.verifyKey,
            method: "POST",
            body: body
        )
        
        guard let data = response.data else {
            throw APIError.serverError(200, response.message)
        }
        return data
    }
    
    // MARK: - Refresh Key Status
    
    func refreshKeyStatus() async throws -> APIResponse<RefreshResult> {
        let device   = DeviceService.shared
        let keyCode  = KeychainService.shared.load(forKey: AppConfig.KeychainKeys.activationKey) ?? ""
        let body: [String: Any] = [
            "key":          keyCode,
            "device_id":    device.deviceIdentifier,
            "ios_version":  device.iosVersion,
        ]
        
        return try await request(
            endpoint: AppConfig.Endpoints.refreshKey,
            method: "POST",
            body: body
        )
    }
    
    // MARK: - App Config
    
    func fetchAppConfig() async throws -> AppConfiguration {
        let response: APIResponse<AppConfiguration> = try await request(
            endpoint: AppConfig.Endpoints.appConfig
        )
        guard let data = response.data else {
            throw APIError.serverError(200, response.message)
        }
        return data
    }
    
    // MARK: - Games
    
    func fetchGames() async throws -> [Game] {
        let response: APIResponse<GamesResponse> = try await request(
            endpoint: AppConfig.Endpoints.games,
            requiresAuth: true
        )
        return response.data?.games ?? []
    }
    
    // MARK: - Categories
    
    func fetchCategories(for gameId: Int) async throws -> CategoriesResponse {
        let response: APIResponse<CategoriesResponse> = try await request(
            endpoint: AppConfig.Endpoints.gameCategories(gameId),
            requiresAuth: true
        )
        guard let data = response.data else {
            throw APIError.serverError(200, response.message)
        }
        return data
    }
    
    // MARK: - Features
    
    func fetchFeatures(for gameId: Int) async throws -> [Feature] {
        let response: APIResponse<FeaturesResponse> = try await request(
            endpoint: AppConfig.Endpoints.gameFeatures(gameId),
            requiresAuth: true
        )
        return response.data?.features ?? []
    }
    
    // MARK: - Active Patch (Single Patch Loader)
    
    func fetchActivePatch(for gameId: Int) async throws -> ActivePatchResponse {
        let response: APIResponse<ActivePatchResponse> = try await request(
            endpoint: AppConfig.Endpoints.activePatch(gameId),
            requiresAuth: true
        )
        guard let data = response.data else {
            throw APIError.serverError(200, response.message)
        }
        return data
    }
    
    // MARK: - File Metadata
    
    func fetchFileMetadata(fileId: Int) async throws -> FileMetadata {
        let response: APIResponse<FileMetadataWrapper> = try await request(
            endpoint: AppConfig.Endpoints.fileMetadata(fileId),
            requiresAuth: true
        )
        guard let data = response.data?.file else {
            throw APIError.notFound
        }
        return data
    }
    
    // MARK: - Request Download Token
    
    func requestDownloadToken(fileId: Int) async throws -> DownloadTokenResponse {
        let response: APIResponse<DownloadTokenResponse> = try await request(
            endpoint: AppConfig.Endpoints.requestDownload(fileId),
            method: "POST",
            requiresAuth: true
        )
        guard let data = response.data else {
            throw APIError.serverError(200, response.message)
        }
        return data
    }
    
    // MARK: - Log Error
    
    func logError(level: String = "error", message: String, context: [String: Any] = [:]) async {
        let body: [String: Any] = ["level": level, "message": message, "context": context]
        _ = try? await request(
            endpoint: AppConfig.Endpoints.logError,
            method: "POST",
            body: body
        ) as APIResponse<EmptyData>
    }
}

// MARK: - Supporting Types

struct RefreshResult: Decodable {
    let key: KeyInfo
    let iosCompatible: String?
    
    enum CodingKeys: String, CodingKey {
        case key
        case iosCompatible = "ios_compatible"
    }
}

struct FileMetadataWrapper: Decodable {
    let file: FileMetadata
}
