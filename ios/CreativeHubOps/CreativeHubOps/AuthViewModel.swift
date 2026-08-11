import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isCheckingSession = true
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    private var didBootstrap = false
    private var authService: SupabaseAuthServicing?
    private var currentUserRepository: CurrentUserRepositoryServing?

    func bootstrap(appState: AppState) async {
        guard !didBootstrap else { return }
        didBootstrap = true
        isCheckingSession = true
        defer { isCheckingSession = false }

        do {
            let service = try makeService()
            authService = service
            if let session = try await service.restoreSession() {
                try await loadCurrentUser(session: session, appState: appState)
            }
        } catch {
            await signOut(appState: appState)
            errorMessage = userFacingMessage(for: error)
        }
    }

    func signIn(email: String, password: String, appState: AppState) async {
        errorMessage = nil
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Vui lòng nhập email và mật khẩu."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let service = try makeService()
            authService = service
            let session = try await service.signIn(email: cleanEmail, password: password)
            try await loadCurrentUser(session: session, appState: appState)
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    func signOut(appState: AppState) async {
        do {
            try await authService?.signOut()
        } catch {
            errorMessage = userFacingMessage(for: error)
        }

        appState.clearSession()
    }

    func updatePassword(email: String, currentPassword: String, newPassword: String, confirmation: String) async throws {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty else {
            throw AppError.validation("Không tìm thấy email tài khoản.")
        }
        guard !currentPassword.isEmpty else {
            throw AppError.validation("Vui lòng nhập mật khẩu hiện tại.")
        }
        guard newPassword.count >= 8 else {
            throw AppError.validation("Mật khẩu mới cần ít nhất 8 ký tự.")
        }
        guard newPassword == confirmation else {
            throw AppError.validation("Xác nhận mật khẩu mới chưa khớp.")
        }

        do {
            let service = try makeService()
            authService = service
            try await service.updatePassword(email: cleanEmail, currentPassword: currentPassword, newPassword: newPassword)
        } catch {
            let mapped = AppError.map(error, fallback: "Không thể cập nhật mật khẩu. Vui lòng thử lại.")
            if case .auth = mapped {
                throw AppError.auth("Mật khẩu hiện tại chưa đúng.")
            }
            throw mapped
        }
    }

    func updateProfile(data: ProfileFormData, appState: AppState) async throws {
        guard appState.can(.profileEditSelf) else {
            throw AppError.permissionDenied
        }
        guard let session = appState.authSession else {
            throw AppError.auth("Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.")
        }

        let repository = try makeCurrentUserRepository()
        try await repository.updateProfile(userId: session.id, data: data)
        let profile = try await repository.fetchCurrentUser(session: session)
        appState.authenticate(with: session, profile: profile)
    }

    func updateAvatar(sourceData: Data, fileName: String, appState: AppState) async throws {
        guard appState.can(.profileEditSelf) else {
            throw AppError.permissionDenied
        }
        guard let session = appState.authSession else {
            throw AppError.auth("Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.")
        }

        let processedData = try await Task.detached(priority: .userInitiated) {
            try AvatarImageProcessor.processedJPEGData(from: sourceData)
        }.value
        let repository = try makeCurrentUserRepository()
        let avatarURL = try await repository.uploadAvatar(
            userId: session.id,
            imageData: processedData,
            fileName: fileName
        )
        do {
            try await repository.updateAvatar(userId: session.id, avatarURL: avatarURL)
        } catch {
            throw AppError.backend("Ảnh đã tải lên nhưng chưa cập nhật được hồ sơ. Vui lòng thử lại.")
        }
        let profile = try await repository.fetchCurrentUser(session: session)
        appState.authenticate(with: session, profile: profile)
    }

    private func makeService() throws -> SupabaseAuthServicing {
        if let authService { return authService }
        return try SupabaseService()
    }

    private func makeCurrentUserRepository() throws -> CurrentUserRepositoryServing {
        if let currentUserRepository { return currentUserRepository }
        let repository = try CurrentUserRepository()
        currentUserRepository = repository
        return repository
    }

    private func loadCurrentUser(session: AuthSessionSnapshot, appState: AppState) async throws {
        let repository = try makeCurrentUserRepository()
        let profile = try await repository.fetchCurrentUser(session: session)
        appState.authenticate(with: session, profile: profile)
    }

    private func userFacingMessage(for error: Error) -> String {
        AppError.map(error, fallback: "Đăng nhập không thành công. Vui lòng thử lại.").localizedDescription
    }
}
