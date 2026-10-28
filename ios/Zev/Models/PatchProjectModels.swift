import Foundation

// MARK: - Patch Rule & Directory Models

struct PatchRule: Codable, Identifiable, Hashable {
    var id: UUID
    var bundleID: String
    var relativePath: String
    var replacementFilename: String
    var replacementData: Data

    init(
        id: UUID = UUID(),
        bundleID: String,
        relativePath: String,
        replacementFilename: String,
        replacementData: Data
    ) {
        self.id = id
        self.bundleID = bundleID
        self.relativePath = relativePath
        self.replacementFilename = replacementFilename
        self.replacementData = replacementData
    }

    var hasReplacement: Bool {
        !replacementFilename.isEmpty
    }
}

struct PatchDirectory: Codable, Identifiable, Hashable {
    var id: UUID
    var bundleID: String
    var relativePath: String

    init(
        id: UUID = UUID(),
        bundleID: String,
        relativePath: String
    ) {
        self.id = id
        self.bundleID = bundleID
        self.relativePath = relativePath
    }
}

struct PatchProject: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var author: String
    var isPrivate: Bool
    var createdAt: Date
    var updatedAt: Date
    var bundleIdentifiers: [String]
    var directories: [PatchDirectory]
    var rules: [PatchRule]

    init(
        id: UUID = UUID(),
        name: String,
        author: String = "",
        isPrivate: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        bundleIdentifiers: [String] = [],
        directories: [PatchDirectory] = [],
        rules: [PatchRule]
    ) {
        self.id = id
        self.name = name
        self.author = author
        self.isPrivate = isPrivate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.bundleIdentifiers = bundleIdentifiers
        self.directories = directories
        self.rules = rules
    }

    var allBundleIdentifiers: [String] {
        var seen = Set<String>()
        return (bundleIdentifiers + directories.map(\.bundleID) + rules.map(\.bundleID))
            .filter { seen.insert($0).inserted }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case author
        case isPrivate
        case createdAt
        case updatedAt
        case bundleIdentifiers
        case directories
        case rules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        bundleIdentifiers = try container.decodeIfPresent(
            [String].self,
            forKey: .bundleIdentifiers
        ) ?? []
        directories = try container.decodeIfPresent(
            [PatchDirectory].self,
            forKey: .directories
        ) ?? []
        rules = try container.decode([PatchRule].self, forKey: .rules)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(author, forKey: .author)
        try container.encode(isPrivate, forKey: .isPrivate)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(bundleIdentifiers, forKey: .bundleIdentifiers)
        try container.encode(directories, forKey: .directories)
        try container.encode(rules, forKey: .rules)
    }
}

enum PatchProjectAccessPolicy {
    static func canInspectContents(
        project: PatchProject,
        isAuthorCopy: Bool
    ) -> Bool {
        !project.isPrivate || isAuthorCopy
    }

    static func shouldMaterializeWorkspace(
        project: PatchProject,
        isAuthorCopy: Bool
    ) -> Bool {
        canInspectContents(project: project, isAuthorCopy: isAuthorCopy)
    }
}

struct PatchPackageSummary: Equatable, Identifiable {
    var id: UUID { packageID }
    let packageID: UUID
    let schemaVersion: Int
    let isPasswordProtected: Bool
    let keyFingerprint: Data
}

struct PatchPackageOrigin: Codable, Equatable, Hashable {
    let repositoryName: String
    let repositoryURL: URL
    let packageIdentifier: String
}

struct EncodedPatchPackage {
    let data: Data
    let contentKey: Data
}

struct DecodedPatchPackage {
    let project: PatchProject
    let contentKey: Data
}

enum PatchPackageError: Error, Equatable, LocalizedError {
    case unsupportedFormat
    case unsupportedVersion
    case invalidPasswordOrCorruptedPackage
    case invalidBundleIdentifier
    case unsafeTargetPath
    case sizeLimitExceeded
    case duplicateTarget
    case invalidProject
    case keychainFailed
    case targetAppUnavailable(String)
    case targetOccupied(String)
    case projectAlreadyApplied
    case restoreTargetsChanged([String])
    case activePatchCannotBeDeleted
    case symbolicLinkUnsupported
    case privatePatchRequiresPassword
    case privateOperationFailed
    case applyFailed
    case restoreFailed
    case resetFailed
    case invalidImportLink
    case remoteImportFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "Định dạng gói .3105 không hợp lệ."
        case .unsupportedVersion: return "Phiên bản gói .3105 không được hỗ trợ."
        case .invalidPasswordOrCorruptedPackage: return "Mật khẩu gói không đúng hoặc file .3105 bị hỏng."
        case .invalidBundleIdentifier: return "Bundle ID trong gói patch không hợp lệ."
        case .unsafeTargetPath: return "Đường dẫn file trong gói patch không an toàn."
        case .sizeLimitExceeded: return "Dung lượng file vượt quá giới hạn."
        case .duplicateTarget: return "Trùng lặp đường dẫn đích trong gói patch."
        case .invalidProject: return "Dự án patch .3105 không hợp lệ."
        case .keychainFailed: return "Lỗi truy cập Keychain."
        case .targetAppUnavailable(let id): return "Không tìm thấy game đích: \(id)"
        case .targetOccupied(let id): return "Thư mục đích đang bị chiếm: \(id)"
        case .projectAlreadyApplied: return "Bản vá đã được áp dụng trước đó."
        case .restoreTargetsChanged(let paths): return "File đã bị thay đổi: \(paths.joined(separator: ", "))"
        case .activePatchCannotBeDeleted: return "Không thể xóa bản vá đang hoạt động."
        case .symbolicLinkUnsupported: return "Không hỗ trợ liên kết tượng trưng (symlink)."
        case .privatePatchRequiresPassword: return "Gói patch riêng tư yêu cầu mật khẩu."
        case .privateOperationFailed: return "Thao tác patch thất bại."
        case .applyFailed: return "Áp dụng bản vá thất bại."
        case .restoreFailed: return "Khôi phục file gốc thất bại."
        case .resetFailed: return "Reset trạng thái thất bại."
        case .invalidImportLink: return "Liên kết nhập patch không hợp lệ."
        case .remoteImportFailed: return "Tải gói patch từ xa thất bại."
        }
    }
}

enum PatchPackageLimits {
    static let maximumPathBytes = 4_096
    static let maximumAuthorBytes = 160
    static let maximumPasswordBytes = 1_024
    static let minimumKDFIterations = 100_000
    static let defaultKDFIterations = 250_000
    static let maximumKDFIterations = 1_000_000
}

enum PatchPathValidator {
    private static let applicationRoot = "/private/var/mobile/Containers/Data/Application"

    static func canonicalBundleIdentifier(_ rawValue: String) throws -> String {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              value.utf8.count <= 255,
              UUID(uuidString: value) == nil,
              !value.contains("/"),
              !value.contains("\\"),
              !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        else {
            throw PatchPackageError.invalidBundleIdentifier
        }

        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count >= 2 else {
            throw PatchPackageError.invalidBundleIdentifier
        }

        for component in components {
            guard !component.isEmpty,
                  component.unicodeScalars.allSatisfy({ scalar in
                      let value = scalar.value
                      return (48...57).contains(value)
                          || (65...90).contains(value)
                          || (97...122).contains(value)
                          || value == 45
                  }),
                  component.first != "-",
                  component.last != "-"
            else {
                throw PatchPackageError.invalidBundleIdentifier
            }
        }
        return value
    }

    static func canonicalRelativePath(_ rawValue: String) throws -> String {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              value.utf8.count <= PatchPackageLimits.maximumPathBytes,
              !value.hasPrefix("/"),
              !value.contains("\\"),
              !value.contains("//"),
              !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        else {
            throw PatchPackageError.unsafeTargetPath
        }

        let components = value.split(separator: "/", omittingEmptySubsequences: false)
        guard components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw PatchPackageError.unsafeTargetPath
        }
        return components.joined(separator: "/")
    }

    static func resolveTargetURL(
        bundleID: String,
        relativePath: String,
        containerRoot: URL
    ) throws -> URL {
        _ = try canonicalBundleIdentifier(bundleID)
        let path = try canonicalRelativePath(relativePath)
        let root = canonicalFileURL(containerRoot)

        guard root.deletingLastPathComponent().path == applicationRoot,
              UUID(uuidString: root.lastPathComponent) != nil
        else {
            throw PatchPackageError.unsafeTargetPath
        }

        return try resolveContainedTargetURL(relativePath: path, containerRoot: root)
    }

    static func resolveContainedTargetURL(relativePath: String, containerRoot: URL) throws -> URL {
        let path = try canonicalRelativePath(relativePath)
        let root = canonicalFileURL(containerRoot)
        let target = root.appendingPathComponent(path, isDirectory: false).standardizedFileURL
        guard target.path.hasPrefix(root.path + "/") else {
            throw PatchPackageError.unsafeTargetPath
        }
        return target
    }

    static func canonicalFileURL(_ url: URL) -> URL {
        var path = url.standardizedFileURL.path
        if path == "/var" || path.hasPrefix("/var/") {
            path = "/private" + path
        }
        return URL(fileURLWithPath: path, isDirectory: url.hasDirectoryPath).standardizedFileURL
    }
}
