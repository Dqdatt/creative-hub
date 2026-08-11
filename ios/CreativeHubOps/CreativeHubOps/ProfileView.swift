import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var avatarMessage: String?

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 12) {
                avatarView
                Text(displayName)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(AppColors.text)
                Text(profileSubtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.secondaryText)
                PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
                    Label("Đổi ảnh đại diện", systemImage: "camera")
                }
                .font(.system(size: 12.5, weight: .black))
                .foregroundStyle(AppColors.accent)
                .disabled(isUploadingAvatar || !appState.can(.profileEditSelf))

                if isUploadingAvatar {
                    ProgressView("Đang tải ảnh...")
                        .font(AppTypography.supporting)
                        .tint(AppColors.accent)
                }

                if let avatarMessage {
                    Text(avatarMessage)
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppColors.danger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.screen)
                }
            }
            .padding(.top, 18)

            settingsGroup("Tài khoản") {
                settingsRow("Cập nhật hồ sơ", "Tên hiển thị, thông tin liên hệ", "person") {
                    appState.activeSheet = .profileEdit
                }
                settingsRow("Đổi mật khẩu", "Bảo mật tài khoản", "lock") {
                    appState.activeSheet = .passwordEdit
                }
            }

            settingsGroup("Không gian làm việc") {
                if appState.can(.contentPlanView) {
                    settingsRow("Content Plan", "Kế hoạch nội dung theo tháng", "list.bullet.rectangle") {
                        appState.path.append(.contentPlan)
                    }
                }
                if PermissionService.canManageUsers(profile: appState.currentProfile) {
                    settingsRow("Nhân sự", "Quản lý user và phân quyền", "person.2") {
                        appState.path.append(.users)
                    }
                }
            }

            settingsGroup("Tuỳ chọn") {
                HStack(spacing: 12) {
                    Image(systemName: "sun.max")
                        .foregroundStyle(AppColors.warning)
                        .frame(width: 34, height: 34)
                        .background(AppColors.warning.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Giao diện sáng")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppColors.text)
                        Text("Tạm khóa light mode cho Phase 3D")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    Spacer()
                }
                .padding(14)
            }

            Button {
                Task {
                    await authViewModel.signOut(appState: appState)
                }
            } label: {
                Label("Đăng xuất", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.danger)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(red: 1, green: 240 / 255, blue: 240 / 255))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, AppSpacing.screen)
        }
        .onChange(of: selectedAvatarItem) { _, newItem in
            guard let newItem else { return }
            Task { await uploadAvatar(from: newItem) }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let url = URL(string: appState.currentProfile?.avatarURL ?? ""), !(appState.currentProfile?.avatarURL ?? "").isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    initialsAvatar
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.72), lineWidth: 3)
            }
            .shadow(color: AppColors.accent.opacity(0.25), radius: 24, x: 0, y: 8)
        } else {
            initialsAvatar
        }
    }

    private var initialsAvatar: some View {
        Text(initials)
            .font(.system(size: 30, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 88, height: 88)
            .background(AppColors.accent)
            .clipShape(Circle())
            .shadow(color: AppColors.accent.opacity(0.35), radius: 24, x: 0, y: 8)
    }

    private var displayName: String {
        appState.currentProfile?.displayName ?? appState.authSession?.email ?? "Người dùng"
    }

    private var profileSubtitle: String {
        guard let profile = appState.currentProfile else {
            return appState.authSession?.email ?? "Đăng nhập Supabase"
        }
        return "\(profile.roleLabel) · \(profile.email)"
    }

    private var initials: String {
        appState.currentProfile?.initials ?? "Đ"
    }

    private func uploadAvatar(from item: PhotosPickerItem) async {
        avatarMessage = nil
        isUploadingAvatar = true
        defer {
            isUploadingAvatar = false
            selectedAvatarItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw AppError.validation("Không đọc được ảnh đã chọn.")
            }
            let fileName = item.supportedContentTypes.first?.preferredFilenameExtension.map { "avatar.\($0)" } ?? "avatar.jpg"
            try await authViewModel.updateAvatar(sourceData: data, fileName: fileName, appState: appState)
        } catch {
            avatarMessage = AppError.map(error, fallback: "Không thể cập nhật ảnh đại diện.").localizedDescription
        }
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.secondaryText)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                content()
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.settings, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 12, y: 2)
        }
        .padding(.horizontal, AppSpacing.screen)
    }

    private func settingsRow(_ title: String, _ subtitle: String, _ image: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: image)
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 34, height: 34)
                    .background(AppColors.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColors.text)
                    Text(subtitle)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(AppColors.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppColors.secondaryText.opacity(0.55))
            }
            .padding(14)
        }
    }
}
