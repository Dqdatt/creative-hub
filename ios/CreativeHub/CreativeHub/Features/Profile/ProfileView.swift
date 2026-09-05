import PhotosUI
import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    var profileID: UUID?
    var fallbackUser: CurrentUserSummary
    var canEdit: Bool
    var refreshShell: (UserProfile) async -> Void
    var signOut: () async -> Bool
    var onShowToast: (CHToastItem) -> Void

    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    Text("profile.root")
                        .font(.system(size: 1))
                        .foregroundStyle(.clear)
                        .frame(width: 1, height: 1)
                        .accessibilityIdentifier("profile.root")
                    content
                }
                .padding(.horizontal, CHSpacing.screen)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .background(CHColors.appBackground.ignoresSafeArea())

            if viewModel.sheetState == .edit, let draft = viewModel.draft, let profile = viewModel.profile {
                ProfileEditOverlay(profile: profile, draft: draft, viewModel: viewModel, onCancel: viewModel.cancelEdit) {
                    Task {
                        let saved = await viewModel.save(refreshShell: refreshShell)
                        onShowToast(CHToastItem(kind: saved ? .success : .error, message: viewModel.mutationError ?? "Đã lưu thay đổi hồ sơ."))
                    }
                }
            }

            if viewModel.sheetState == .password {
                ProfilePasswordOverlay(
                    viewModel: viewModel,
                    onCancel: { viewModel.sheetState = .none },
                    onSave: {
                        Task {
                            let saved = await viewModel.changePassword()
                            onShowToast(CHToastItem(kind: saved ? .success : .error, message: viewModel.mutationError ?? "Đã cập nhật mật khẩu."))
                        }
                    }
                )
            }

            if viewModel.sheetState == .logoutConfirm {
                ProfileLogoutOverlay(
                    isProcessing: viewModel.isSigningOut,
                    onCancel: { viewModel.sheetState = .none },
                    onConfirm: {
                        Task {
                            guard !viewModel.isSigningOut else { return }
                            viewModel.isSigningOut = true
                            let signedOut = await signOut()
                            viewModel.isSigningOut = false
                            if !signedOut {
                                onShowToast(CHToastItem(kind: .error, message: "Không thể đăng xuất. Vui lòng thử lại."))
                            }
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: profileID) {
            viewModel.configure(profileID: profileID, fallback: fallbackUser, canEdit: canEdit)
            await viewModel.load()
        }
        .refreshable {
            if let message = await viewModel.refresh(refreshShell: refreshShell) {
                onShowToast(CHToastItem(kind: .error, message: message))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            CHStateView(kind: .loading, title: "Đang tải hồ sơ...")
                .frame(minHeight: 560)
                .accessibilityIdentifier("profile.loading")
        case .failed(let message):
            CHStateView(
                kind: .error,
                title: "Không thể tải hồ sơ",
                message: message,
                actionTitle: "Thử lại",
                action: { Task { await viewModel.load() } }
            )
            .frame(minHeight: 560)
            .accessibilityIdentifier("profile.load-error")
        case .loaded:
            if let profile = viewModel.profile {
                loadedContent(profile)
            }
        }
    }

    private func loadedContent(_ profile: UserProfile) -> some View {
        VStack(spacing: 10) {
            CHCard {
                VStack(spacing: 13) {
                    ProfileAvatarView(profile: profile, previewData: nil, size: 88)
                        .accessibilityIdentifier(profile.avatarURL == nil ? "profile.avatar.initials" : "profile.avatar.remote")
                    Text(profile.avatarURL == nil ? "profile.avatar.initials.marker" : "profile.avatar.remote.marker")
                        .font(.system(size: 1))
                        .foregroundStyle(.clear)
                        .frame(width: 1, height: 1)
                        .accessibilityIdentifier(profile.avatarURL == nil ? "profile.avatar.initials.marker" : "profile.avatar.remote.marker")

                    VStack(spacing: 4) {
                        Text(profile.displayIdentity)
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(CHColors.ink)
                            .multilineTextAlignment(.center)
                        Text(profile.email)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CHColors.muted)
                            .lineLimit(1)
                    }

                    HStack(spacing: 7) {
                        ProfileChip(text: profile.roleLabel, accent: CHColors.purple)
                        ProfileChip(text: profile.statusLabel, accent: Color(hex: 0x16A34A))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(16)
            }
            .accessibilityIdentifier("profile.summary")

            ProfileMetadataCard(profile: profile)

            ProfileContractCard(
                canEdit: canEdit,
                onEdit: viewModel.openEdit,
                onPassword: viewModel.openPassword,
                onLogout: { viewModel.sheetState = .logoutConfirm }
            )

            Text("profile.bottom")
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("profile.bottom")
        }
    }
}

private struct ProfileAvatarView: View {
    var profile: UserProfile
    var previewData: Data?
    var size: CGFloat

    var body: some View {
        ZStack {
            if let previewData, let image = UIImage(data: previewData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = profile.avatarURL {
                #if DEBUG
                if url.scheme == "creativehub-fixture-avatar" {
                    ProfileFixtureAvatarArtwork()
                } else {
                    remoteAvatar(url)
                }
                #else
                remoteAvatar(url)
                #endif
            } else {
                initials
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).stroke(Color.white.opacity(0.7), lineWidth: 1))
        .shadow(color: CHShadow.softColor, radius: 12, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(profile.avatarURL == nil ? profile.initials : "Ảnh đại diện")
        .accessibilityIdentifier(profile.avatarURL == nil ? "profile.avatar.initials" : "profile.avatar.remote")
    }

    private func remoteAvatar(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                initials
            }
        }
    }

    private var initials: some View {
        ZStack {
            CHColors.primaryGradient
            Text(profile.initials)
                .font(.system(size: max(18, size * 0.34), weight: .heavy))
                .foregroundStyle(.white)
        }
    }
}

#if DEBUG
private struct ProfileFixtureAvatarArtwork: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xE0F2FE), Color(hex: 0xEEF2FF), Color(hex: 0xDCFCE7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color(hex: 0xF8D7C4))
                .frame(width: 38, height: 38)
                .offset(y: -15)
            Circle()
                .fill(Color(hex: 0x172033))
                .frame(width: 42, height: 24)
                .offset(y: -29)
                .clipShape(Circle())
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(hex: 0x2563EB))
                .frame(width: 66, height: 46)
                .offset(y: 31)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.38))
                .frame(width: 34, height: 8)
                .offset(y: 22)
        }
    }
}
#endif

private struct ProfileChip: View {
    var text: String
    var accent: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.12))
                    .overlay(Capsule().stroke(accent.opacity(0.24), lineWidth: 1))
            )
    }
}

private struct ProfileMetadataCard: View {
    var profile: UserProfile

    var body: some View {
        CHCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Thông tin tài khoản")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(CHColors.ink)
                ContractRow(title: "Họ tên", value: profile.fullName)
                ContractRow(title: "Tên hiển thị", value: profile.displayName)
                ContractRow(title: "Email", value: profile.email)
                ContractRow(title: "Số điện thoại", value: profile.phone.profileNonEmpty ?? "Chưa cập nhật")
                ContractRow(title: "Bộ phận", value: profile.department)
                ContractRow(title: "Vai trò", value: profile.roleLabel)
                ContractRow(title: "Trạng thái", value: profile.statusLabel)
                if let editorIdentity = profile.editorIdentityLabel {
                    ContractRow(title: "Định danh editor", value: editorIdentity)
                }
            }
            .padding(14)
        }
        .accessibilityIdentifier("profile.metadata")
    }
}

private struct ProfileContractCard: View {
    var canEdit: Bool
    var onEdit: () -> Void
    var onPassword: () -> Void
    var onLogout: () -> Void

    var body: some View {
        CHCard {
            VStack(spacing: 9) {
                Button(action: onEdit) {
                    Label("Chỉnh sửa hồ sơ", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CHPrimaryButtonStyle())
                .disabled(!canEdit)
                .opacity(canEdit ? 1 : 0.45)
                .accessibilityIdentifier("profile.edit")

                Button(action: onPassword) {
                    Label("Đổi mật khẩu", systemImage: "key.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CHSecondaryButtonStyle())
                .accessibilityIdentifier("profile.password")

                Button(action: onLogout) {
                    Label("Đăng xuất", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CHDestructiveButtonStyle())
                .accessibilityIdentifier("profileLogoutButton")
            }
            .padding(12)
        }
    }
}

private struct ContractRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(CHColors.muted)
            Spacer(minLength: 6)
            Text(value)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(CHColors.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 3)
    }
}

private struct ProfileEditOverlay: View {
    var profile: UserProfile
    var draft: ProfileDraft
    @ObservedObject var viewModel: ProfileViewModel
    var onCancel: () -> Void
    var onSave: () -> Void
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.32).ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        Text("profile.edit.sheet")
                            .font(.system(size: 1))
                            .foregroundStyle(.clear)
                            .frame(width: 1, height: 1)
                            .accessibilityIdentifier("profile.edit.sheet")

                        Text("Chỉnh sửa hồ sơ")
                            .font(.system(size: 19, weight: .heavy))
                            .foregroundStyle(CHColors.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ProfileAvatarView(profile: profile, previewData: viewModel.avatarPreviewData, size: 76)
                            .frame(maxWidth: .infinity)

                        HStack(spacing: 8) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("Đổi ảnh", systemImage: "photo")
                                    .font(.system(size: 12, weight: .heavy))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(CHSecondaryButtonStyle())
                            .accessibilityIdentifier("profile.avatar.pick")

                            Button(action: viewModel.removeAvatar) {
                                Label("Xóa ảnh", systemImage: "trash")
                                    .font(.system(size: 12, weight: .heavy))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(CHSecondaryButtonStyle())
                            .accessibilityIdentifier("profile.avatar.remove")
                        }

                        ProfileField(title: "Họ tên", text: Binding(
                            get: { draft.fullName },
                            set: { value in viewModel.updateDraft { $0.fullName = value } }
                        ), identifier: "profile.form.full-name")
                        ProfileField(title: "Tên hiển thị", text: Binding(
                            get: { draft.displayName },
                            set: { value in viewModel.updateDraft { $0.displayName = value } }
                        ), identifier: "profile.form.display-name")
                        ProfileReadonlyField(title: "Email", value: profile.email, identifier: "profile.form.email")
                        ProfileField(title: "Số điện thoại", text: Binding(
                            get: { draft.phone },
                            set: { value in viewModel.updateDraft { $0.phone = value } }
                        ), identifier: "profile.form.phone")
                        ProfileReadonlyField(title: "Vai trò", value: profile.roleLabel, identifier: "profile.form.role")
                        ProfileField(title: "Bộ phận", text: Binding(
                            get: { draft.department },
                            set: { value in viewModel.updateDraft { $0.department = value } }
                        ), identifier: "profile.form.department")

                        if let editorIdentity = profile.editorIdentityLabel {
                            ProfileReadonlyField(title: "Định danh editor", value: editorIdentity, identifier: "profile.form.editor")
                        }

                        if let error = viewModel.mutationError {
                            Text(error)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(hex: 0xB42318))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("profile.save-error")
                        }

                        Text("profile.edit.bottom")
                            .font(.system(size: 1))
                            .foregroundStyle(.clear)
                            .frame(width: 1, height: 1)
                            .accessibilityIdentifier("profile.edit.bottom")
                    }
                    .padding(14)
                    .padding(.bottom, 98)
                }

                actionBar
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.84)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(CHColors.appBackground)
                    .shadow(color: CHShadow.softColor, radius: 22, y: -4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .task(id: selectedPhoto) {
            guard let selectedPhoto else { return }
            do {
                guard let data = try await selectedPhoto.loadTransferable(type: Data.self) else {
                    viewModel.mutationError = "Không thể đọc ảnh đã chọn."
                    return
                }
                let supported = selectedPhoto.supportedContentTypes.first
                let fileExtension = supported?.preferredFilenameExtension ?? "jpg"
                let contentType = supported?.preferredMIMEType ?? "image/jpeg"
                viewModel.selectAvatar(data: data, fileExtension: fileExtension, contentType: contentType)
            } catch {
                viewModel.mutationError = "Không thể đọc ảnh đã chọn."
            }
        }
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("profile.action-bar")

            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Text("Hủy")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CHSecondaryButtonStyle())
                .accessibilityIdentifier("profile.edit.cancel")

                Button(action: onSave) {
                    HStack(spacing: 6) {
                        if viewModel.isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text(viewModel.isSaving ? "Đang lưu..." : "Lưu thay đổi")
                            .lineLimit(1)
                            .minimumScaleFactor(0.86)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(CHPrimaryButtonStyle())
                .disabled(viewModel.isSaving)
                .accessibilityIdentifier("profile.edit.save")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, CHSpacing.screen)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .fill(CHColors.appBackground)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(CHColors.line)
                .frame(height: 1)
        }
    }
}

private struct ProfileField: View {
    var title: String
    @Binding var text: String
    var identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(CHColors.muted)
            TextField(title, text: $text)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(CHColors.ink)
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.white.opacity(0.82))
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(CHColors.line, lineWidth: 1))
                )
                .accessibilityIdentifier(identifier)
        }
    }
}

private struct ProfileReadonlyField: View {
    var title: String
    var value: String
    var identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(CHColors.muted)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(CHColors.muted)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.white.opacity(0.46))
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(CHColors.line, lineWidth: 1))
                )
                .accessibilityIdentifier(identifier)
        }
    }
}

private struct ProfilePasswordOverlay: View {
    @ObservedObject var viewModel: ProfileViewModel
    var onCancel: () -> Void
    var onSave: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.32).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("profile.password.sheet")
                    .font(.system(size: 1))
                    .foregroundStyle(.clear)
                    .frame(width: 1, height: 1)
                    .accessibilityIdentifier("profile.password.sheet")
                Text("Đổi mật khẩu")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(CHColors.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SecureProfileField(title: "Mật khẩu hiện tại", text: Binding(
                    get: { viewModel.passwordDraft.currentPassword },
                    set: { viewModel.passwordDraft.currentPassword = $0 }
                ), identifier: "profile.password.current")
                SecureProfileField(title: "Mật khẩu mới", text: Binding(
                    get: { viewModel.passwordDraft.newPassword },
                    set: { viewModel.passwordDraft.newPassword = $0 }
                ), identifier: "profile.password.new")
                SecureProfileField(title: "Xác nhận mật khẩu mới", text: Binding(
                    get: { viewModel.passwordDraft.confirmPassword },
                    set: { viewModel.passwordDraft.confirmPassword = $0 }
                ), identifier: "profile.password.confirm")

                if let error = viewModel.mutationError {
                    Text(error)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: 0xB42318))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 10) {
                    Button("Hủy", action: onCancel)
                        .buttonStyle(CHSecondaryButtonStyle())
                        .accessibilityIdentifier("profile.password.cancel")
                    Button(action: onSave) {
                        if viewModel.isPasswordSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Cập nhật mật khẩu")
                        }
                    }
                    .buttonStyle(CHPrimaryButtonStyle())
                    .accessibilityIdentifier("profile.password.save")
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(CHColors.appBackground)
                    .shadow(color: CHShadow.softColor, radius: 22, y: -4)
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }
}

private struct SecureProfileField: View {
    var title: String
    @Binding var text: String
    var identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(CHColors.muted)
            SecureField(title, text: $text)
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.white.opacity(0.82))
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(CHColors.line, lineWidth: 1))
                )
                .accessibilityIdentifier(identifier)
        }
    }
}

private struct ProfileLogoutOverlay: View {
    var isProcessing: Bool
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.34).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text("Đăng xuất?")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(CHColors.ink)
                Text("Bạn sẽ quay về màn hình đăng nhập.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CHColors.muted)
                HStack(spacing: 10) {
                    Button("Hủy", action: onCancel)
                        .buttonStyle(CHSecondaryButtonStyle())
                        .disabled(isProcessing)
                        .opacity(isProcessing ? 0.55 : 1)
                        .accessibilityIdentifier("logoutCancelButton")
                    Button(action: onConfirm) {
                        HStack(spacing: 7) {
                            if isProcessing {
                                ProgressView()
                                    .scaleEffect(0.76)
                                    .accessibilityIdentifier("logoutProcessingIndicator")
                            }
                            Text("Đăng xuất")
                        }
                        .frame(maxWidth: .infinity)
                    }
                        .buttonStyle(CHDestructiveButtonStyle())
                        .disabled(isProcessing)
                        .accessibilityIdentifier("logoutConfirmButton")
                }
            }
            .padding(22)
            .frame(maxWidth: 328, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.96))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.white.opacity(0.72), lineWidth: 1))
                    .shadow(color: CHShadow.softColor, radius: 24, y: 14)
            )
            .padding(.horizontal, 32)
            .accessibilityIdentifier("logoutConfirmation")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
