import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 14) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .padding(14)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.10), radius: 24, x: 0, y: 6)

                Text("CreativeHub Ops")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColors.text)

                Text("Hệ thống quản lý Video Task & Lịch quay")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            AppCard {
                VStack(spacing: 16) {
                    field("Email công việc", text: $email, systemImage: "envelope", keyboard: .emailAddress)
                    secureField

                    if let errorMessage = authViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await login() }
                    } label: {
                        HStack(spacing: 7) {
                            if authViewModel.isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Đăng nhập")
                            }
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(authViewModel.isSubmitting)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.bottom, 24)
        .background(AppColors.background.ignoresSafeArea())
    }

    private var secureField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mật khẩu")
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(AppColors.text.opacity(0.75))
            HStack(spacing: 10) {
                Image(systemName: "lock")
                    .foregroundStyle(AppColors.secondaryText)
                SecureField("Mật khẩu", text: $password)
                    .textContentType(.password)
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(AppColors.chip)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.search, style: .continuous))
        }
    }

    private func field(_ title: String, text: Binding<String>, systemImage: String, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(AppColors.text.opacity(0.75))
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(AppColors.secondaryText)
                TextField(title, text: text)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.username)
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(AppColors.chip)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.search, style: .continuous))
        }
    }

    private func login() async {
        await authViewModel.signIn(email: email, password: password, appState: appState)
    }
}
