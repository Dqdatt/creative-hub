import Foundation
import UniformTypeIdentifiers

enum ProfileLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

enum ProfileSheetState: Equatable {
    case none
    case edit
    case password
    case logoutConfirm
}

struct PendingAvatar: Equatable {
    var data: Data
    var fileExtension: String
    var contentType: String
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var loadState: ProfileLoadState = .idle
    @Published private(set) var profile: UserProfile?
    @Published var draft: ProfileDraft?
    @Published var passwordDraft = PasswordDraft()
    @Published var sheetState: ProfileSheetState = .none
    @Published var isSaving = false
    @Published var isPasswordSaving = false
    @Published var isSigningOut = false
    @Published var mutationError: String?
    @Published var localError: String?
    @Published var avatarPreviewData: Data?
    @Published var avatarRemoved = false
    @Published var pendingAvatar: PendingAvatar?

    let provider: ProfileDataProviding
    private var currentProfileID: UUID?
    private var fallbackUser: CurrentUserSummary = .empty

    init(provider: ProfileDataProviding = ProfileProviderFactory.makeProvider()) {
        self.provider = provider
    }

    var canEdit: Bool = true

    func configure(profileID: UUID?, fallback: CurrentUserSummary, canEdit: Bool) {
        self.currentProfileID = profileID
        self.fallbackUser = fallback
        self.canEdit = canEdit
    }

    func loadIfNeeded() async {
        if case .idle = loadState {
            await load()
        }
    }

    func load() async {
        guard let currentProfileID else {
            loadState = .failed("Vui lòng thử lại.")
            return
        }
        loadState = .loading
        mutationError = nil
        localError = nil
        do {
            let nextProfile = try await provider.fetchProfile(profileID: currentProfileID, fallback: fallbackUser)
            profile = nextProfile
            draft = ProfileDraft(profile: nextProfile)
            passwordDraft = PasswordDraft()
            avatarPreviewData = nil
            avatarRemoved = false
            pendingAvatar = nil
            loadState = .loaded
        } catch {
            if AsyncCancellation.isCancellation(error) {
                return
            }
            profile = nil
            loadState = .failed(Self.safeMessage(for: error, fallback: "Vui lòng thử lại."))
        }
    }

    func refresh(refreshShell: (UserProfile) async -> Void) async -> String? {
        guard let currentProfileID else {
            return "Không thể tải hồ sơ. Vui lòng thử lại."
        }

        do {
            let nextProfile = try await provider.fetchProfile(profileID: currentProfileID, fallback: fallbackUser)
            profile = nextProfile
            if sheetState == .none {
                draft = ProfileDraft(profile: nextProfile)
                passwordDraft = PasswordDraft()
                avatarPreviewData = nil
                avatarRemoved = false
                pendingAvatar = nil
            }
            loadState = .loaded
            await refreshShell(nextProfile)
            return nil
        } catch {
            if AsyncCancellation.isCancellation(error) {
                return nil
            }
            let message = Self.safeMessage(for: error, fallback: "Không thể tải hồ sơ. Vui lòng thử lại.")
            if profile == nil {
                loadState = .failed(message)
            }
            return message
        }
    }

    func openEdit() {
        guard canEdit, let profile else { return }
        draft = ProfileDraft(profile: profile)
        avatarPreviewData = nil
        avatarRemoved = false
        pendingAvatar = nil
        mutationError = nil
        localError = nil
        sheetState = .edit
    }

    func cancelEdit() {
        if let profile {
            draft = ProfileDraft(profile: profile)
        }
        avatarPreviewData = nil
        avatarRemoved = false
        pendingAvatar = nil
        mutationError = nil
        localError = nil
        sheetState = .none
    }

    func updateDraft(_ patch: (inout ProfileDraft) -> Void) {
        guard var nextDraft = draft else { return }
        patch(&nextDraft)
        draft = nextDraft
        mutationError = nil
        localError = nil
    }

    func selectAvatar(data: Data, fileExtension: String, contentType: String) {
        guard data.count <= 2 * 1024 * 1024 else {
            mutationError = "Ảnh đại diện tối đa 2MB."
            return
        }
        pendingAvatar = PendingAvatar(data: data, fileExtension: fileExtension, contentType: contentType)
        avatarPreviewData = data
        avatarRemoved = false
        mutationError = nil
    }

    func removeAvatar() {
        pendingAvatar = nil
        avatarPreviewData = nil
        avatarRemoved = true
        mutationError = nil
    }

    func save(refreshShell: (UserProfile) async -> Void) async -> Bool {
        guard canEdit, let currentProfileID, let draft else { return false }
        if let validation = ProfileValidation.validate(draft) {
            mutationError = validation
            return false
        }

        isSaving = true
        mutationError = nil
        defer { isSaving = false }

        do {
            let nextAvatarURL: URL?
            if let pendingAvatar {
                do {
                    nextAvatarURL = try await provider.uploadAvatar(
                        profileID: currentProfileID,
                        data: pendingAvatar.data,
                        fileExtension: pendingAvatar.fileExtension,
                        contentType: pendingAvatar.contentType
                    )
                } catch {
                    if AsyncCancellation.isCancellation(error) {
                        return false
                    }
                    mutationError = Self.safeMessage(for: error, fallback: "Không thể xử lý ảnh đại diện. Vui lòng thử lại.")
                    return false
                }
            } else if avatarRemoved {
                nextAvatarURL = nil
            } else {
                nextAvatarURL = profile?.avatarURL
            }
            try await provider.updateProfile(profileID: currentProfileID, draft: draft, avatarURL: nextAvatarURL)
            let reloaded = try await provider.fetchProfile(profileID: currentProfileID, fallback: fallbackUser)
            profile = reloaded
            self.draft = ProfileDraft(profile: reloaded)
            await refreshShell(reloaded)
            avatarPreviewData = nil
            avatarRemoved = false
            pendingAvatar = nil
            sheetState = .none
            loadState = .loaded
            return true
        } catch {
            if AsyncCancellation.isCancellation(error) {
                return false
            }
            mutationError = Self.safeMessage(for: error, fallback: "Không thể lưu hồ sơ. Vui lòng thử lại.")
            return false
        }
    }

    func openPassword() {
        passwordDraft = PasswordDraft()
        mutationError = nil
        localError = nil
        sheetState = .password
    }

    func changePassword() async -> Bool {
        guard let email = profile?.email.profileNonEmpty else {
            mutationError = "Không tìm thấy email tài khoản."
            return false
        }
        if let validation = ProfileValidation.validatePassword(
            current: passwordDraft.currentPassword,
            next: passwordDraft.newPassword,
            confirm: passwordDraft.confirmPassword
        ) {
            mutationError = validation
            return false
        }

        isPasswordSaving = true
        mutationError = nil
        defer { isPasswordSaving = false }

        do {
            try await provider.changePassword(
                email: email,
                currentPassword: passwordDraft.currentPassword,
                newPassword: passwordDraft.newPassword
            )
            passwordDraft = PasswordDraft()
            sheetState = .none
            return true
        } catch {
            if AsyncCancellation.isCancellation(error) {
                return false
            }
            mutationError = Self.safeMessage(for: error, fallback: "Không thể cập nhật mật khẩu. Vui lòng thử lại.")
            return false
        }
    }

    func signOut() async {
        await provider.signOut()
    }

    static func safeMessage(for error: Error, fallback: String) -> String {
        if AsyncCancellation.isCancellation(error) {
            return fallback
        }
        let raw = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let unsafeMarkers = ["fixture", "backend", "rpc", "sql", "supabase", "postgrest", "uuid", "row-level", "storage", "auth"]
        if raw.isEmpty || unsafeMarkers.contains(where: { raw.localizedCaseInsensitiveContains($0) }) {
            return fallback
        }
        return raw
    }
}
