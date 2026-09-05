import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack {
            CHColors.background
                .ignoresSafeArea()

            switch appState.authentication {
            case .checkingSession:
                SessionCheckingView()
                    .transition(.systemStateEntrance)
            case .signedOut, .signingIn:
                LoginView()
                    .transition(.systemStateEntrance)
            case .authenticated:
                AppShellView()
                    .transition(.opacity)
            case .empty:
                SystemStateScreen(
                    topbarTitle: "Dữ liệu",
                    kind: .empty,
                    title: "Chưa có dữ liệu",
                    message: "Dữ liệu sẽ xuất hiện ở đây sau khi bạn tạo nội dung đầu tiên."
                )
                    .transition(.systemStateEntrance)
            case .offline:
                SystemStateScreen(
                    topbarTitle: "Kết nối",
                    kind: .offline,
                    title: "Không có kết nối mạng",
                    message: "Kiểm tra Wi‑Fi hoặc dữ liệu di động rồi thử lại.",
                    actionTitle: "Thử lại",
                    action: appState.retryBootstrap
                )
                    .transition(.systemStateEntrance)
            case .loadError:
                SystemStateScreen(
                    topbarTitle: "Có lỗi xảy ra",
                    kind: .error,
                    title: "Không thể tải dữ liệu",
                    message: "Hệ thống đang gặp sự cố tạm thời. Vui lòng thử lại.",
                    actionTitle: "Thử lại",
                    action: appState.retryBootstrap
                )
                    .transition(.systemStateEntrance)
            case .forbidden:
                SystemStateScreen(
                    topbarTitle: "Quyền truy cập",
                    kind: .forbidden,
                    title: "Bạn không có quyền truy cập",
                    message: "Tài khoản hiện tại chưa được cấp quyền cho khu vực này.",
                    secondaryActionTitle: "Quay lại",
                    topbarBackAction: appState.returnToLogin,
                    action: appState.returnToLogin
                )
                    .transition(.systemStateEntrance)
            case .sessionExpired:
                SystemStateScreen(
                    kind: .sessionExpired,
                    title: "Phiên đăng nhập đã hết hạn",
                    message: "Đăng nhập lại để tiếp tục sử dụng CreativeHub.",
                    actionTitle: "Đăng nhập lại",
                    action: appState.returnToLogin
                )
                .transition(.systemStateEntrance)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = appState.toast {
                CHToast(item: toast)
                    .padding(.bottom, toastBottomPadding)
                    .transition(.offset(y: CHToastPresentation.hiddenOffsetY).combined(with: .opacity))
                    .onTapGesture {
                        withAnimation(.snappy) {
                            appState.dismissToast()
                        }
                    }
            }
        }
        .animation(.timingCurve(0.22, 0.86, 0.28, 1, duration: 0.26), value: appState.authentication)
        .animation(.easeOut(duration: CHToastPresentation.transitionDuration), value: appState.toast)
        .onChange(of: appState.authentication) { _, state in
            switch state {
            case .authenticated:
                router.resetToAuthenticatedRoot()
            case .checkingSession, .signingIn:
                break
            case .signedOut, .empty, .offline, .loadError, .forbidden, .sessionExpired:
                router.resetForLogout()
            }
        }
        .task {
            await appState.start()
        }
    }

    private var toastBottomPadding: CGFloat {
        CHToastPlacement.bottomPadding(
            authentication: appState.authentication,
            isBottomNavigationVisible: router.isBottomNavigationVisible
        )
    }
}

private struct LoginView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                HStack(spacing: 9) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(CHColors.primaryGradient)
                            .frame(width: 40, height: 40)
                            .shadow(color: CHColors.purple.opacity(0.20), radius: 12, y: 8)
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    HStack(spacing: 0) {
                        Text("Creative")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundStyle(CHColors.ink)
                        Text("Hub")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundStyle(CHColors.blue)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 26)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Đăng nhập")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(CHColors.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LoginField(
                        title: "Email",
                        icon: "envelope",
                        text: $appState.loginEmail,
                        contentType: .username,
                        keyboardType: .emailAddress
                    )

                    LoginSecureField(
                        title: "Mật khẩu",
                        icon: "lock",
                        text: $appState.loginPassword
                    )

                    if let error = appState.loginError {
                        Text(error)
                            .font(CHTypography.caption)
                            .foregroundStyle(CHColors.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("login-error")
                    }

                    HStack {
                        Spacer()
                        Button("Quên mật khẩu?") {
                            appState.requestPasswordReset()
                        }
                        .font(CHTypography.caption)
                        .foregroundStyle(CHColors.blue)
                        .accessibilityIdentifier("forgot-password")
                    }

                    Button {
                        Task {
                            await appState.signIn()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if appState.isLoginSubmitting {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(appState.isLoginSubmitting ? "Đang đăng nhập" : "Đăng nhập")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SystemPrimaryButtonStyle(height: 45))
                    .disabled(appState.isLoginSubmitting)
                    .opacity(appState.isLoginSubmitting ? 0.72 : 1)
                    .accessibilityIdentifier("login-submit")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
                .padding(.bottom, -2)
                .frame(maxWidth: 366)
                .background(
                    RoundedRectangle(cornerRadius: 27, style: .continuous)
                        .fill(Color.white.opacity(0.86))
                        .overlay(
                            RoundedRectangle(cornerRadius: 27, style: .continuous)
                                .stroke(Color(red: 203 / 255, green: 211 / 255, blue: 229 / 255).opacity(0.78), lineWidth: 1)
                        )
                        .shadow(color: Color(red: 79 / 255, green: 91 / 255, blue: 133 / 255).opacity(0.10), radius: 22, y: 18)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Login card")
                        .accessibilityIdentifier("login-card")
                )

                Spacer(minLength: 28)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .alert(item: $appState.passwordRecoveryInfo) { info in
            Alert(
                title: Text(info.title),
                message: Text(info.message),
                dismissButton: .default(Text("Đã hiểu")) {
                    appState.dismissPasswordRecoveryInfo()
                }
            )
        }
        .background(CHColors.background.ignoresSafeArea())
    }
}

private struct LoginField: View {
    var title: String
    var icon: String
    @Binding var text: String
    var contentType: UITextContentType?
    var keyboardType: UIKeyboardType

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(CHColors.muted)
                .padding(.leading, 3)

            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CHColors.muted)
                    .frame(width: 18)
                TextField("", text: $text)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(CHColors.ink)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(contentType)
                    .keyboardType(keyboardType)
                    .accessibilityIdentifier("login-email")
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(LinearGradient(colors: [.white, Color(red: 248 / 255, green: 249 / 255, blue: 253 / 255)], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(CHColors.line))
            )
        }
    }
}

private struct LoginSecureField: View {
    var title: String
    var icon: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(CHColors.muted)
                .padding(.leading, 3)

            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CHColors.muted)
                    .frame(width: 18)
                SecureField("Nhập mật khẩu", text: $text)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(CHColors.ink)
                    .textContentType(.password)
                    .accessibilityIdentifier("login-password")
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(LinearGradient(colors: [.white, Color(red: 248 / 255, green: 249 / 255, blue: 253 / 255)], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(CHColors.line))
            )
        }
    }
}

private struct SessionCheckingView: View {
    @State private var isBreathing = false

    var body: some View {
        VStack(spacing: 18) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .opacity(isBreathing ? 1 : 0.82)
                .scaleEffect(isBreathing ? 1 : 0.97)
                .accessibilityIdentifier("session-bootstrap-logo")

            RingSpinner()
                .accessibilityIdentifier("session-bootstrap-spinner")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CHColors.background.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }
}

private struct SystemStateScreen: View {
    var topbarTitle: String? = nil
    var kind: CHStateKind
    var title: String
    var message: String
    var actionTitle: String? = nil
    var secondaryActionTitle: String? = nil
    var topbarBackAction: (() -> Void)? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            if let topbarTitle {
                SystemStateTopBar(title: topbarTitle, onBack: topbarBackAction)
            }

            VStack {
                VStack(spacing: 16) {
                    StateIcon(kind: kind)

                    VStack(spacing: 7) {
                        Text(title)
                            .font(CHTypography.headline)
                            .foregroundStyle(CHColors.ink)
                            .multilineTextAlignment(.center)
                        Text(message)
                            .font(CHTypography.caption)
                            .foregroundStyle(CHColors.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let actionTitle, let action {
                        Button(action: action) {
                            Text(actionTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SystemPrimaryButtonStyle(height: 44))
                        .padding(.top, 2)
                        .accessibilityIdentifier("system-state-primary-action")
                    }

                    if let secondaryActionTitle, let action {
                        Button(action: action) {
                            Text(secondaryActionTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SystemSecondaryButtonStyle())
                        .accessibilityIdentifier("system-state-secondary-action")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: 330)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(kind == .loading ? 0 : 0.86))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color(red: 203 / 255, green: 211 / 255, blue: 229 / 255).opacity(kind == .loading ? 0 : 0.78), lineWidth: 1)
                        )
                        .shadow(color: Color(red: 79 / 255, green: 91 / 255, blue: 133 / 255).opacity(kind == .loading ? 0 : 0.10), radius: 22, y: 18)
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
        }
        .background(CHColors.background.ignoresSafeArea())
    }
}

private struct SystemStateTopBar: View {
    var title: String
    var onBack: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(CHColors.ink)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color(red: 249 / 255, green: 250 / 255, blue: 253 / 255).opacity(0.92))
                                    .overlay(Circle().stroke(Color(red: 194 / 255, green: 203 / 255, blue: 223 / 255).opacity(0.66), lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Quay lại")
                    .accessibilityIdentifier("system-state-back")
                } else {
                    Color.clear
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 42, alignment: .leading)

            Text(title)
                .font(CHTypography.subheadline)
                .foregroundStyle(CHColors.ink)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("system-state-title")

            Color.clear
                .frame(width: 42, height: 1)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 7)
        .frame(height: 46)
        .background(
            Capsule(style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.82), Color.white.opacity(0.54)], startPoint: .top, endPoint: .bottom))
                .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.85), lineWidth: 1))
                .shadow(color: Color(red: 62 / 255, green: 74 / 255, blue: 118 / 255).opacity(0.08), radius: 15, y: 10)
        )
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }
}

private struct RingSpinner: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: 0xE8E7F4), lineWidth: 4)
            Circle()
                .trim(from: 0, to: 0.24)
                .stroke(CHColors.purple, style: StrokeStyle(lineWidth: 4, lineCap: .butt))
                .rotationEffect(.degrees(rotation))
        }
        .frame(width: 54, height: 54)
        .shadow(color: Color(red: 83 / 255, green: 81 / 255, blue: 151 / 255).opacity(0.08), radius: 9, y: 8)
        .accessibilityIdentifier("loading-ring")
        .onAppear {
            rotation = 0
            withAnimation(.linear(duration: 0.75).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

private struct SystemPrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(CHColors.primaryGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color(red: 87 / 255, green: 82 / 255, blue: 255 / 255).opacity(0.18), radius: 11, y: 10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct SystemSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .bold))
            .foregroundStyle(Color(hex: 0x6857FF))
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(Color.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: 0x705BFF).opacity(0.30), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct SystemEntranceModifier: ViewModifier {
    var isActive: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 0.55 : 1)
            .offset(x: isActive ? 26 : 0)
    }
}

private extension AnyTransition {
    @MainActor
    static var systemStateEntrance: AnyTransition {
        AnyTransition.modifier(
            active: SystemEntranceModifier(isActive: true),
            identity: SystemEntranceModifier(isActive: false)
        )
    }
}

private struct StateIcon: View {
    var kind: CHStateKind

    var body: some View {
        switch kind {
        case .empty:
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0xF0EDFF), Color(hex: 0xEAF1FF)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(CHColors.purple.opacity(0.10)))
                    .frame(width: 66, height: 48)
                    .offset(y: 18)
                Circle()
                    .fill(CHColors.primaryGradient)
                    .frame(width: 34, height: 34)
                    .shadow(color: CHColors.purple.opacity(0.18), radius: 8, y: 8)
            }
            .frame(width: 92, height: 74)
        case .error:
            iconCircle(name: "arrow.clockwise", color: CHColors.red)
        case .offline:
            iconCircle(name: "link", color: CHColors.orange)
        case .forbidden:
            iconCircle(name: "lock.fill", color: CHColors.muted)
        case .sessionExpired:
            iconCircle(name: "lock.fill", color: CHColors.purple)
        case .loading:
            ProgressView()
                .tint(CHColors.purple)
                .frame(width: 54, height: 54)
        }
    }

    private func iconCircle(name: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.10))
                .frame(width: 58, height: 58)
            Image(systemName: name)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(color)
        }
    }
}

#Preview("Root Authenticated") {
    RootView()
        .environmentObject(AppState())
        .environmentObject(AppRouter())
}
