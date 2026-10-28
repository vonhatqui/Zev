import Foundation

// MARK: - API Response Models

struct APIResponse<T: Decodable>: Decodable {
    let status: String
    let message: String
    let data: T?
}

struct EmptyData: Decodable {}

// MARK: - Flexible Decoding Helpers (Khắc phục hoàn toàn lệch kiểu Int/String từ MySQL và SQLite)

extension KeyedDecodingContainer {
    func decodeFlexibleInt(forKey key: Key) throws -> Int {
        if let val = try? decode(Int.self, forKey: key) {
            return val
        }
        if let str = try? decode(String.self, forKey: key), let val = Int(str.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return val
        }
        if let dbl = try? decode(Double.self, forKey: key) {
            return Int(dbl)
        }
        return 0
    }
    
    func decodeFlexibleIntIfPresent(forKey key: Key) -> Int? {
        if let val = try? decodeIfPresent(Int.self, forKey: key) {
            return val
        }
        if let str = try? decodeIfPresent(String.self, forKey: key), let val = Int(str.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return val
        }
        if let dbl = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(dbl)
        }
        return nil
    }
    
    func decodeFlexibleBool(forKey key: Key) -> Bool {
        if let val = try? decode(Bool.self, forKey: key) {
            return val
        }
        if let intVal = try? decode(Int.self, forKey: key) {
            return intVal == 1
        }
        if let strVal = try? decode(String.self, forKey: key) {
            let s = strVal.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return s == "1" || s == "true"
        }
        return false
    }
}

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
    
    init(code: String, status: String, expiresAt: String?, isLifetime: Bool) {
        self.code = code
        self.status = status
        self.expiresAt = expiresAt
        self.isLifetime = isLifetime
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.code = (try? c.decode(String.self, forKey: .code)) ?? ""
        self.status = (try? c.decode(String.self, forKey: .status)) ?? "active"
        self.expiresAt = try? c.decodeIfPresent(String.self, forKey: .expiresAt)
        self.isLifetime = c.decodeFlexibleBool(forKey: .isLifetime)
    }
    
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
    
    init(id: Int, bundleId: String, displayName: String, shortName: String, logoUrl: String?, description: String?, sortOrder: Int) {
        self.id = id
        self.bundleId = bundleId
        self.displayName = displayName
        self.shortName = shortName
        self.logoUrl = logoUrl
        self.description = description
        self.sortOrder = sortOrder
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeFlexibleInt(forKey: .id)
        self.bundleId = (try? c.decode(String.self, forKey: .bundleId)) ?? ""
        self.displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        self.shortName = (try? c.decode(String.self, forKey: .shortName)) ?? ""
        self.logoUrl = try? c.decodeIfPresent(String.self, forKey: .logoUrl)
        self.description = try? c.decodeIfPresent(String.self, forKey: .description)
        self.sortOrder = (try? c.decodeFlexibleInt(forKey: .sortOrder)) ?? 0
    }
    
    var isInstalled: Bool {
        GameDetectionService.shared.checkInstallation(bundleId: bundleId).isInstalled
    }
    
    var installationStatusText: String {
        isInstalled ? "Sẵn sàng" : "Chưa Cài Đặt"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case bundleId    = "bundle_id"
        case displayName = "display_name"
        case shortName   = "short_name"
        case logoUrl     = "logo_url"
        case description
        case sortOrder   = "sort_order"
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
    
    init(id: Int, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeFlexibleInt(forKey: .id)
        self.displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
    }
    
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
    
    init(id: Int, slug: String, displayName: String, logoUrl: String?, description: String?, sortOrder: Int, featureCount: Int? = nil, readyCount: Int? = nil) {
        self.id = id
        self.slug = slug
        self.displayName = displayName
        self.logoUrl = logoUrl
        self.description = description
        self.sortOrder = sortOrder
        self.featureCount = featureCount
        self.readyCount = readyCount
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeFlexibleInt(forKey: .id)
        self.slug = (try? c.decode(String.self, forKey: .slug)) ?? ""
        self.displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        self.logoUrl = try? c.decodeIfPresent(String.self, forKey: .logoUrl)
        self.description = try? c.decodeIfPresent(String.self, forKey: .description)
        self.sortOrder = (try? c.decodeFlexibleInt(forKey: .sortOrder)) ?? 0
        self.featureCount = c.decodeFlexibleIntIfPresent(forKey: .featureCount)
        self.readyCount = c.decodeFlexibleIntIfPresent(forKey: .readyCount)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, slug
        case displayName  = "display_name"
        case logoUrl      = "logo_url"
        case description
        case sortOrder    = "sort_order"
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
    let filePassword: String?
    let configFileId: Int?
    let configFileName: String?
    
    init(id: Int, slug: String, displayName: String, description: String?, status: FeatureStatus, fileId: Int?, fileName: String?, previewUrl: String?, categoryId: Int?, categoryName: String?, fileVersion: String?, fileSize: Int?, targetPath: String?, checksumSha256: String?, filePassword: String? = nil, configFileId: Int? = nil, configFileName: String? = nil) {
        self.id = id
        self.slug = slug
        self.displayName = displayName
        self.description = description
        self.status = status
        self.fileId = fileId
        self.fileName = fileName
        self.previewUrl = previewUrl
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.fileVersion = fileVersion
        self.fileSize = fileSize
        self.targetPath = targetPath
        self.checksumSha256 = checksumSha256
        self.filePassword = filePassword
        self.configFileId = configFileId
        self.configFileName = configFileName
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeFlexibleInt(forKey: .id)
        self.slug = (try? c.decode(String.self, forKey: .slug)) ?? ""
        self.displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        self.description = try? c.decodeIfPresent(String.self, forKey: .description)
        self.status = (try? c.decode(FeatureStatus.self, forKey: .status)) ?? .unsupported
        self.fileId = c.decodeFlexibleIntIfPresent(forKey: .fileId)
        self.fileName = try? c.decodeIfPresent(String.self, forKey: .fileName)
        self.previewUrl = try? c.decodeIfPresent(String.self, forKey: .previewUrl)
        self.categoryId = c.decodeFlexibleIntIfPresent(forKey: .categoryId)
        self.categoryName = try? c.decodeIfPresent(String.self, forKey: .categoryName)
        self.fileVersion = try? c.decodeIfPresent(String.self, forKey: .fileVersion)
        self.fileSize = c.decodeFlexibleIntIfPresent(forKey: .fileSize)
        self.targetPath = try? c.decodeIfPresent(String.self, forKey: .targetPath)
        self.checksumSha256 = try? c.decodeIfPresent(String.self, forKey: .checksumSha256)
        self.filePassword = try? c.decodeIfPresent(String.self, forKey: .filePassword)
        self.configFileId = c.decodeFlexibleIntIfPresent(forKey: .configFileId)
        self.configFileName = try? c.decodeIfPresent(String.self, forKey: .configFileName)
    }
    
    var hasFile: Bool {
        fileId != nil && (status == .ready || status == .loading)
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
        case filePassword   = "file_password"
        case configFileId   = "config_file_id"
        case configFileName = "config_file_name"
    }
}

// MARK: - Active Patch (Single Patch Workflow: Loader -> Injector -> Uninjector)

struct ActivePatchResponse: Decodable {
    let hasPatch: Bool
    let patch: ActiveGamePatch?
    
    enum CodingKeys: String, CodingKey {
        case hasPatch = "has_patch"
        case patch
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.hasPatch = (try? c.decode(Bool.self, forKey: .hasPatch)) ?? false
        self.patch = try? c.decodeIfPresent(ActiveGamePatch.self, forKey: .patch)
    }
}

struct ActiveGamePatch: Decodable, Identifiable {
    let id: Int
    let displayName: String
    let status: String
    let fileId: Int
    let fileName: String
    let fileSize: Int
    let targetPath: String?
    let checksumSha256: String?
    let filePassword: String?
    let configFileId: Int?
    let configFileName: String?
    let configFileSize: Int?
    let configTargetPath: String?
    
    enum CodingKeys: String, CodingKey {
        case id, status
        case displayName        = "display_name"
        case fileId             = "file_id"
        case fileName           = "file_name"
        case fileSize           = "file_size"
        case targetPath         = "target_path"
        case checksumSha256     = "checksum_sha256"
        case filePassword       = "file_password"
        case configFileId       = "config_file_id"
        case configFileName     = "config_file_name"
        case configFileSize     = "config_file_size"
        case configTargetPath   = "config_target_path"
    }
    
    init(id: Int, displayName: String, status: String, fileId: Int, fileName: String, fileSize: Int, targetPath: String?, checksumSha256: String?, filePassword: String? = nil, configFileId: Int? = nil, configFileName: String? = nil, configFileSize: Int? = nil, configTargetPath: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.status = status
        self.fileId = fileId
        self.fileName = fileName
        self.fileSize = fileSize
        self.targetPath = targetPath
        self.checksumSha256 = checksumSha256
        self.filePassword = filePassword
        self.configFileId = configFileId
        self.configFileName = configFileName
        self.configFileSize = configFileSize
        self.configTargetPath = configTargetPath
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeFlexibleInt(forKey: .id)
        self.displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        self.status = (try? c.decode(String.self, forKey: .status)) ?? "ready"
        self.fileId = (try? c.decodeFlexibleInt(forKey: .fileId)) ?? 0
        self.fileName = (try? c.decode(String.self, forKey: .fileName)) ?? ""
        self.fileSize = (try? c.decodeFlexibleInt(forKey: .fileSize)) ?? 0
        self.targetPath = try? c.decodeIfPresent(String.self, forKey: .targetPath)
        self.checksumSha256 = try? c.decodeIfPresent(String.self, forKey: .checksumSha256)
        self.filePassword = try? c.decodeIfPresent(String.self, forKey: .filePassword)
        self.configFileId = c.decodeFlexibleIntIfPresent(forKey: .configFileId)
        self.configFileName = try? c.decodeIfPresent(String.self, forKey: .configFileName)
        self.configFileSize = c.decodeFlexibleIntIfPresent(forKey: .configFileSize)
        self.configTargetPath = try? c.decodeIfPresent(String.self, forKey: .configTargetPath)
    }
    
    var is3105Package: Bool {
        fileName.lowercased().hasSuffix(".3105")
    }
    
    var formattedSize: String {
        let bytes = Double(fileSize)
        if bytes > 1024 * 1024 {
            return String(format: "%.2f MB", bytes / (1024 * 1024))
        } else if bytes > 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        }
        return "\(fileSize) B"
    }
}

enum FeatureStatus: String, Decodable {
    case ready         = "ready"
    case loading       = "loading"
    case unsupported   = "unsupported"
    case noFile        = "no_file"
    case incompatible  = "incompatible"
    case error         = "error"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? ""
        self = FeatureStatus(rawValue: raw) ?? .unsupported
    }
    
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
    
    init(id: Int, displayName: String, fileSize: Int, mimeType: String?, checksumSha256: String, fileVersion: String?, status: String, gameName: String?) {
        self.id = id
        self.displayName = displayName
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.checksumSha256 = checksumSha256
        self.fileVersion = fileVersion
        self.status = status
        self.gameName = gameName
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeFlexibleInt(forKey: .id)
        self.displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        self.fileSize = (try? c.decodeFlexibleInt(forKey: .fileSize)) ?? 0
        self.mimeType = try? c.decodeIfPresent(String.self, forKey: .mimeType)
        self.checksumSha256 = (try? c.decode(String.self, forKey: .checksumSha256)) ?? ""
        self.fileVersion = try? c.decodeIfPresent(String.self, forKey: .fileVersion)
        self.status = (try? c.decode(String.self, forKey: .status)) ?? "active"
        self.gameName = try? c.decodeIfPresent(String.self, forKey: .gameName)
    }
    
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
    
    init(downloadUrl: String, expiresAt: String, fileSize: Int, checksum: String) {
        self.downloadUrl = downloadUrl
        self.expiresAt = expiresAt
        self.fileSize = fileSize
        self.checksum = checksum
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.downloadUrl = (try? c.decode(String.self, forKey: .downloadUrl)) ?? ""
        self.expiresAt = (try? c.decode(String.self, forKey: .expiresAt)) ?? ""
        self.fileSize = (try? c.decodeFlexibleInt(forKey: .fileSize)) ?? 0
        self.checksum = (try? c.decode(String.self, forKey: .checksum)) ?? ""
    }
    
    enum CodingKeys: String, CodingKey {
        case downloadUrl = "download_url"
        case expiresAt   = "expires_at"
        case fileSize    = "file_size"
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
