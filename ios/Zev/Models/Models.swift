import Foundation

// MARK: - API Response Models

struct APIResponse<T: Decodable>: Decodable {
    let status: String
    let message: String
    let data: T?
}

struct EmptyData: Decodable {}

// MARK: - Activation Key

struct ActivationResult: Decodable {
    let key: KeyInfo
    let device: DeviceInfo
}

struct KeyInfo: Decodable {
    let code: String
    let status: String
    let expiresAt: String?
    let isLifetime: Bool
    
    enum CodingKeys: String, CodingKey {
        case code, status
        case expiresAt   = "expires_at"
        case isLifetime  = "is_lifetime"
    }
    
    var expiryDate: Date? {
        guard let str = expiresAt else { return nil }
        if let d = DateFormatter.serverDate.date(from: str) { return d }
        let iso1 = ISO8601DateFormatter()
        iso1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso1.date(from: str) { return d }
        let iso2 = ISO8601DateFormatter()
        iso2.formatOptions = [.withInternetDateTime]
        return iso2.date(from: str)
    }
    
    var isExpired: Bool {
        guard let date = expiryDate else { return false }
        return Date() > date
    }
    
    var displayExpiry: String {
        if isLifetime { return "Vĩnh viễn" }
        guard let date = expiryDate else { return expiresAt ?? "—" }
        let diff = Calendar.current.dateComponents([.day, .hour], from: Date(), to: date)
        let days = diff.day ?? 0
        let hours = diff.hour ?? 0
        let dateStr = DateFormatter.displayDate.string(from: date)
        if days > 0 {
            return "\(dateStr) (Còn \(days) ngày)"
        } else if hours > 0 {
            return "\(dateStr) (Còn \(hours) giờ)"
        } else if date < Date() {
            return "\(dateStr) (Đã hết hạn)"
        }
        return dateStr
    }
}

struct DeviceInfo: Decodable {
    let model: String?
    let iosVersion: String?
    let appVersion: String?
    let iosCompatible: String?
    
    enum CodingKeys: String, CodingKey {
        case model, iosVersion = "ios_version"
        case appVersion = "app_version"
        case iosCompatible = "ios_compatible"
    }
}

// MARK: - App Config

struct AppConfiguration: Codable {
    let config: [String: String]
    let iosCompatibility: [IOSCompatibility]
    let serverTime: String?
    
    enum CodingKeys: String, CodingKey {
        case config
        case iosCompatibility = "ios_compatibility"
        case serverTime = "server_time"
    }
}

struct IOSCompatibility: Codable {
    let iosVersion: String
    let status: String  // "supported" | "unsupported" | "partial"
    let note: String?
    
    enum CodingKeys: String, CodingKey {
        case iosVersion = "ios_version"
        case status, note
    }
}

// MARK: - Games

struct GamesResponse: Decodable {
    let games: [Game]
}

struct Game: Decodable, Identifiable {
    let id: Int
    let bundleId: String
    let displayName: String
    let shortName: String
    let logoUrl: String?
    let description: String?
    let sortOrder: Int
    
    var isInstalled: Bool {
        GameDetectionService.shared.checkInstallation(bundleId: bundleId).isInstalled
    }
    
    var installationStatusText: String {
        isInstalled ? "Sẵn sàng" : "Chưa Cài Đặt"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case bundleId   = "bundle_id"
        case displayName = "display_name"
        case shortName   = "short_name"
        case logoUrl     = "logo_url"
        case description, sortOrder = "sort_order"
    }
}

// MARK: - Feature Categories

struct CategoriesResponse: Decodable {
    let game: GameBrief
    let categories: [FeatureCategory]
}

struct GameBrief: Decodable {
    let id: Int
    let displayName: String
    
    enum CodingKeys: String, CodingKey {
        case id, displayName = "display_name"
    }
}

struct FeatureCategory: Decodable, Identifiable {
    let id: Int
    let slug: String
    let displayName: String
    let logoUrl: String?
    let description: String?
    let sortOrder: Int
    let featureCount: Int?
    let readyCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, slug
        case displayName  = "display_name"
        case logoUrl      = "logo_url"
        case description, sortOrder = "sort_order"
        case featureCount = "feature_count"
        case readyCount   = "ready_count"
    }
}

// MARK: - Features

struct FeaturesResponse: Decodable {
    let features: [Feature]
}

struct Feature: Decodable, Identifiable {
    let id: Int
    let slug: String
    let displayName: String
    let description: String?
    let status: FeatureStatus
    let fileId: Int?
    let fileName: String?
    let previewUrl: String?
    let categoryId: Int?
    let categoryName: String?
    let fileVersion: String?
    let fileSize: Int?
    let targetPath: String?
    let checksumSha256: String?
    
    var hasFile: Bool {
        fileId != nil && status == .ready
    }
    
    enum CodingKeys: String, CodingKey {
        case id, slug, description, status
        case displayName    = "display_name"
        case fileId         = "file_id"
        case fileName       = "file_name"
        case previewUrl     = "preview_url"
        case categoryId     = "category_id"
        case categoryName   = "category_name"
        case fileVersion    = "file_version"
        case fileSize       = "file_size"
        case targetPath     = "target_path"
        case checksumSha256 = "checksum_sha256"
    }
}

enum FeatureStatus: String, Decodable {
    case ready         = "ready"
    case loading       = "loading"
    case unsupported   = "unsupported"
    case noFile        = "no_file"
    case incompatible  = "incompatible"
    case error         = "error"
    
    var displayText: String {
        switch self {
        case .ready:       return NSLocalizedString("Sẵn sàng", comment: "")
        case .loading:     return NSLocalizedString("Đang tải", comment: "")
        case .unsupported: return NSLocalizedString("Chưa hỗ trợ", comment: "")
        case .noFile:      return NSLocalizedString("Chưa có file", comment: "")
        case .incompatible:return NSLocalizedString("Không tương thích", comment: "")
        case .error:       return NSLocalizedString("Lỗi kết nối", comment: "")
        }
    }
    
    var isActionable: Bool { self == .ready }
}

// MARK: - File

struct FileMetadata: Decodable {
    let id: Int
    let displayName: String
    let fileSize: Int
    let mimeType: String?
    let checksumSha256: String
    let fileVersion: String?
    let status: String
    let gameName: String?
    
    enum CodingKeys: String, CodingKey {
        case id, status
        case displayName    = "display_name"
        case fileSize       = "file_size"
        case mimeType       = "mime_type"
        case checksumSha256 = "checksum_sha256"
        case fileVersion    = "file_version"
        case gameName       = "game_name"
    }
}

struct DownloadTokenResponse: Decodable {
    let downloadUrl: String
    let expiresAt: String
    let fileSize: Int
    let checksum: String
    
    enum CodingKeys: String, CodingKey {
        case downloadUrl = "download_url"
        case expiresAt  = "expires_at"
        case fileSize   = "file_size"
        case checksum
    }
}

// MARK: - Date Formatters

extension DateFormatter {
    static let serverDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    static let displayDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy HH:mm"
        f.locale = Locale.current
        return f
    }()
}
