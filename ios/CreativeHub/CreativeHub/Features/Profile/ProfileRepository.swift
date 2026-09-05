import Foundation
import Supabase
import UniformTypeIdentifiers

protocol ProfileDataProviding: Sendable {
    var usesProductionData: Bool { get }
    func fetchProfile(profileID: UUID, fallback: CurrentUserSummary) async throws -> UserProfile
    func updateProfile(profileID: UUID, draft: ProfileDraft, avatarURL: URL?) async throws
    func uploadAvatar(profileID: UUID, data: Data, fileExtension: String, contentType: String) async throws -> URL
    func changePassword(email: String, currentPassword: String, newPassword: String) async throws
    func signOut() async
}

enum ProfileRepositoryError: LocalizedError, Equatable {
    case configurationMissing
    case missingProfile
    case backend(String)

    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            "Kết nối hồ sơ chưa sẵn sàng."
        case .missingProfile:
            "Chưa tìm thấy hồ sơ người dùng."
        case .backend(let message):
            message
        }
    }
}

struct ProfileSupabaseRepository: ProfileDataProviding {
    var usesProductionData: Bool { true }

    private let client: SupabaseClient?
    private let avatarBucket = "avatars"

    init(client: SupabaseClient? = SupabaseService.shared.client) {
        self.client = client
    }

    func fetchProfile(profileID: UUID, fallback: CurrentUserSummary) async throws -> UserProfile {
        guard let client else { throw ProfileRepositoryError.configurationMissing }
        do {
            let row: ProfileDTO? = try await client
                .from("profiles")
                .select("""
                    id,
                    email,
                    full_name,
                    display_name,
                    short_name,
                    phone,
                    role,
                    department,
                    avatar_url,
                    editor_code,
                    is_editor_member,
                    active,
                    is_active
                """)
                .eq("id", value: profileID)
                .maybeSingle()
                .execute()
                .value
            guard let row else { throw ProfileRepositoryError.missingProfile }
            return row.profile(fallback: fallback)
        } catch let error as ProfileRepositoryError {
            throw error
        } catch let error as PostgrestError {
            throw ProfileRepositoryError.backend(Self.safeDatabaseMessage(error.message, code: error.code))
        } catch {
            throw ProfileRepositoryError.backend(Self.safeDatabaseMessage(error.localizedDescription, code: nil))
        }
    }

    func updateProfile(profileID: UUID, draft: ProfileDraft, avatarURL: URL?) async throws {
        guard let client else { throw ProfileRepositoryError.configurationMissing }
        let payload = ProfileUpdatePayload(
            fullName: draft.fullName.trimmingCharacters(in: .whitespacesAndNewlines),
            displayName: draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            shortName: draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: draft.phone.trimmingCharacters(in: .whitespacesAndNewlines).profileNonEmpty,
            department: draft.department.trimmingCharacters(in: .whitespacesAndNewlines).profileNonEmpty ?? "Team Marketing",
            avatarURL: avatarURL?.absoluteString
        )
        do {
            try await client
                .from("profiles")
                .update(payload)
                .eq("id", value: profileID)
                .execute()
        } catch let error as PostgrestError {
            throw ProfileRepositoryError.backend(Self.safeDatabaseMessage(error.message, code: error.code))
        } catch {
            throw ProfileRepositoryError.backend(Self.safeDatabaseMessage(error.localizedDescription, code: nil))
        }
    }

    func uploadAvatar(profileID: UUID, data: Data, fileExtension: String, contentType: String) async throws -> URL {
        guard let client else { throw ProfileRepositoryError.configurationMissing }
        let path = Self.avatarStoragePath(profileID: profileID, timestamp: Date().timeIntervalSince1970, fileExtension: fileExtension)
        do {
            try await client.storage
                .from(avatarBucket)
                .upload(path, data: data, options: FileOptions(contentType: contentType, upsert: true))
            return try client.storage
                .from(avatarBucket)
                .getPublicURL(path: path)
        } catch {
            throw ProfileRepositoryError.backend(Self.safeStorageMessage(error.localizedDescription))
        }
    }

    func changePassword(email: String, currentPassword: String, newPassword: String) async throws {
        guard let client else { throw ProfileRepositoryError.configurationMissing }
        do {
            _ = try await client.auth.signIn(email: email, password: currentPassword)
        } catch {
            throw ProfileRepositoryError.backend("Mật khẩu hiện tại chưa đúng.")
        }
        do {
            _ = try await client.auth.update(user: UserAttributes(password: newPassword))
        } catch let error as AuthError {
            let message = error.message.lowercased()
            if message.contains("weak password") || message.contains("should be at least") {
                throw ProfileRepositoryError.backend("Mật khẩu mới chưa đủ mạnh.")
            }
            if message.contains("requires recent login") || message.contains("reauthentication") {
                throw ProfileRepositoryError.backend("Phiên đăng nhập cần xác thực lại trước khi đổi mật khẩu.")
            }
            throw ProfileRepositoryError.backend("Không thể cập nhật mật khẩu. Vui lòng thử lại.")
        } catch {
            throw ProfileRepositoryError.backend("Không thể cập nhật mật khẩu. Vui lòng thử lại.")
        }
    }

    func signOut() async {
        guard let client else { return }
        try? await client.auth.signOut()
    }

    static func avatarStoragePath(profileID: UUID, timestamp: TimeInterval, fileExtension: String) -> String {
        "\(profileID.uuidString)/\(Int(timestamp))-avatar.\(Self.cleanFileExtension(fileExtension))"
    }

    private static func cleanFileExtension(_ value: String) -> String {
        let clean = value.lowercased().filter { $0.isLetter || $0.isNumber }
        return clean.isEmpty ? "jpg" : clean
    }

    private static func safeDatabaseMessage(_ message: String, code: String?) -> String {
        let lower = message.lowercased()
        if code == "42501" || lower.contains("row-level security") || lower.contains("permission denied") {
            return "Bạn không có quyền cập nhật hồ sơ này."
        }
        if lower.contains("failed to fetch") || lower.contains("network") {
            return "Không thể kết nối máy chủ. Vui lòng kiểm tra mạng."
        }
        if lower.contains("violates check constraint") {
            return "Dữ liệu hồ sơ chưa đúng định dạng."
        }
        return "Không thể xử lý hồ sơ. Vui lòng thử lại."
    }

    private static func safeStorageMessage(_ message: String) -> String {
        let lower = message.lowercased()
        if lower.contains("bucket not found") || lower.contains("not found") {
            return "Chưa thể lưu ảnh đại diện. Vui lòng liên hệ quản trị viên."
        }
        if lower.contains("row-level security") || lower.contains("permission denied") || lower.contains("403") {
            return "Bạn không có quyền tải ảnh đại diện."
        }
        if lower.contains("payload too large") || lower.contains("exceeded") {
            return "Ảnh đại diện quá lớn."
        }
        return "Không thể xử lý ảnh đại diện. Vui lòng thử lại."
    }
}

struct ProfileDTO: Decodable {
    var id: UUID
    var email: String?
    var fullName: String?
    var displayName: String?
    var shortName: String?
    var phone: String?
    var role: String?
    var department: String?
    var avatarURL: String?
    var editorCode: String?
    var isEditorMember: Bool?
    var active: Bool?
    var isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case displayName = "display_name"
        case shortName = "short_name"
        case phone
        case role
        case department
        case avatarURL = "avatar_url"
        case editorCode = "editor_code"
        case isEditorMember = "is_editor_member"
        case active
        case isActive = "is_active"
    }

    func profile(fallback: CurrentUserSummary) -> UserProfile {
        let resolvedDisplayName = displayName.profileNonEmpty ?? shortName.profileNonEmpty ?? fullName.profileNonEmpty ?? fallback.displayName
        let resolvedFullName = fullName.profileNonEmpty ?? resolvedDisplayName
        let resolvedRole = CreativeHubRole(rawValue: role)
        return UserProfile(
            id: id,
            email: email.profileNonEmpty ?? fallback.email,
            fullName: resolvedFullName,
            displayName: resolvedDisplayName,
            shortName: shortName.profileNonEmpty,
            phone: phone.profileNonEmpty ?? "",
            department: department.profileNonEmpty ?? "Team Marketing",
            role: resolvedRole,
            rawRole: role,
            avatarURL: avatarURL.profileNonEmpty.flatMap(URL.init(string:)) ?? fallback.avatarURL,
            editorCode: editorCode.profileNonEmpty,
            isEditorMember: isEditorMember ?? (editorCode.profileNonEmpty != nil || resolvedRole == .editor),
            isActive: isActive ?? active ?? true
        )
    }
}

struct ProfileUpdatePayload: Encodable {
    var fullName: String
    var displayName: String
    var shortName: String
    var phone: String?
    var department: String
    var avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case displayName = "display_name"
        case shortName = "short_name"
        case phone
        case department
        case avatarURL = "avatar_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fullName, forKey: .fullName)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(shortName, forKey: .shortName)
        try container.encodeIfPresent(phone, forKey: .phone)
        if phone == nil {
            try container.encodeNil(forKey: .phone)
        }
        try container.encode(department, forKey: .department)
        try container.encodeIfPresent(avatarURL, forKey: .avatarURL)
        if avatarURL == nil {
            try container.encodeNil(forKey: .avatarURL)
        }
    }
}
