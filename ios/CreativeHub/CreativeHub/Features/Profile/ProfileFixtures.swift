import Foundation

actor ProfileFixtureRepository: ProfileDataProviding {
    enum Mode: String {
        case normal
        case editor
        case avatar
        case initials
        case saveError = "save-error"
        case avatarUploadError = "avatar-upload-error"
        case loadError = "load-error"
        case passwordError = "password-error"
    }

    nonisolated var usesProductionData: Bool { false }

    private let mode: Mode
    private var profile: UserProfile
    private(set) var didSignOut = false

    init(mode: String?) {
        self.mode = Mode(rawValue: mode ?? "normal") ?? .normal
        switch self.mode {
        case .editor:
            profile = Self.editorProfile
        case .avatar, .avatarUploadError:
            profile = Self.avatarProfile
        case .initials:
            profile = Self.initialsProfile
        default:
            profile = Self.normalProfile
        }
    }

    func fetchProfile(profileID: UUID, fallback: CurrentUserSummary) async throws -> UserProfile {
        if mode == .loadError {
            throw ProfileRepositoryError.backend("Fixture Supabase profile load error")
        }
        return profile
    }

    func updateProfile(profileID: UUID, draft: ProfileDraft, avatarURL: URL?) async throws {
        if mode == .saveError {
            throw ProfileRepositoryError.backend("Fixture row-level security profile update error")
        }
        profile.fullName = draft.fullName
        profile.displayName = draft.displayName
        profile.phone = draft.phone
        profile.department = draft.department.profileNonEmpty ?? "Team Marketing"
        profile.avatarURL = avatarURL
    }

    func uploadAvatar(profileID: UUID, data: Data, fileExtension: String, contentType: String) async throws -> URL {
        if mode == .saveError || mode == .avatarUploadError {
            throw ProfileRepositoryError.backend("Fixture storage upload error")
        }
        return URL(string: "https://example.test/avatars/\(profileID.uuidString)/phase10-avatar.\(fileExtension)")!
    }

    func changePassword(email: String, currentPassword: String, newPassword: String) async throws {
        if mode == .passwordError {
            throw ProfileRepositoryError.backend("Fixture auth password update error")
        }
    }

    func signOut() async {
        didSignOut = true
    }

    static let profileID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    static let normalProfile = UserProfile(
        id: profileID,
        email: "dat@creativehub.local",
        fullName: "Đoàn Quốc Đạt",
        displayName: "Đạt Đoàn",
        shortName: "Đạt",
        phone: "0901 234 567",
        department: "Team Marketing",
        role: .admin,
        rawRole: "admin",
        avatarURL: nil,
        editorCode: "dat",
        isEditorMember: true,
        isActive: true
    )

    static let editorProfile = UserProfile(
        id: profileID,
        email: "hai@creativehub.local",
        fullName: "Nguyễn Thanh Hải",
        displayName: "Thanh Hải",
        shortName: "Hải",
        phone: "",
        department: "Video",
        role: .editor,
        rawRole: "editor",
        avatarURL: nil,
        editorCode: "hai",
        isEditorMember: true,
        isActive: true
    )

    static let avatarProfile = UserProfile(
        id: profileID,
        email: "minh@creativehub.local",
        fullName: "Hoàng Hữu Lê Minh",
        displayName: "Hữu Minh",
        shortName: "Minh",
        phone: "0909 888 777",
        department: "Creative",
        role: .creativeManager,
        rawRole: "creative_manager",
        avatarURL: URL(string: "creativehub-fixture-avatar://minh"),
        editorCode: "minh",
        isEditorMember: true,
        isActive: true
    )

    static let initialsProfile = UserProfile(
        id: profileID,
        email: "creator@creativehub.local",
        fullName: "Lê Demo",
        displayName: "Demo",
        shortName: nil,
        phone: "",
        department: "Team Marketing",
        role: .contentCreator,
        rawRole: "content_creator",
        avatarURL: nil,
        editorCode: nil,
        isEditorMember: false,
        isActive: true
    )
}

enum ProfileProviderFactory {
    static func makeProvider() -> ProfileDataProviding {
        #if DEBUG
        if let mode = ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE10_PROFILE_FIXTURE"] {
            return ProfileFixtureRepository(mode: mode)
        }
        #endif
        return ProfileSupabaseRepository()
    }
}
