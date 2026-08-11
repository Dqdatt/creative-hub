import SwiftUI

enum AppColors {
    static let background = Color(red: 232 / 255, green: 235 / 255, blue: 242 / 255)
    static let card = Color.white
    static let text = Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255)
    static let secondaryText = Color(red: 154 / 255, green: 160 / 255, blue: 178 / 255)
    static let accent = Color(red: 124 / 255, green: 92 / 255, blue: 255 / 255)
    static let success = Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255)
    static let warning = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)
    static let danger = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)
    static let chip = Color(red: 237 / 255, green: 237 / 255, blue: 243 / 255)
}

enum AppSpacing {
    static let screen: CGFloat = 16
    static let small: CGFloat = 8
    static let medium: CGFloat = 14
    static let large: CGFloat = 22
}

enum AppRadius {
    static let search: CGFloat = 12
    static let card: CGFloat = 12
    static let settings: CGFloat = 12
    static let sheet: CGFloat = 22
}

enum AppTypography {
    static let navTitle = Font.system(size: 16, weight: .bold)
    static let heroTitle = Font.system(size: 21, weight: .black)
    static let sectionLabel = Font.system(size: 11.5, weight: .black)
    static let rowLabel = Font.system(size: 13, weight: .semibold)
    static let rowValue = Font.system(size: 13, weight: .bold)
    static let supporting = Font.system(size: 12, weight: .semibold)
}

struct AppCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(.black.opacity(0.04), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 2)
    }
}

struct AppSecondaryTopBar<Trailing: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    var backTitle = "Quay lại"
    let trailing: Trailing

    init(title: String, backTitle: String = "Quay lại", @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.backTitle = backTitle
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            Text(title)
                .font(AppTypography.navTitle)
                .foregroundStyle(AppColors.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            HStack {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                        Text(backTitle)
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(AppColors.text)
                    .frame(minHeight: 44)
                }
                .accessibilityLabel(backTitle)

                Spacer()

                trailing
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
            }
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(AppColors.background)
    }
}

struct AppSecondaryScreen<Content: View, Trailing: View>: View {
    let title: String
    let trailing: Trailing
    let content: Content

    init(title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            AppSecondaryTopBar(title: title) {
                trailing
            }
            ScrollView {
                VStack(spacing: 12) {
                    content
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.light)
    }
}

struct AppDetailHeroCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(AppTypography.heroTitle)
                    .foregroundStyle(AppColors.text)
                    .lineLimit(3)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppColors.secondaryText)
                }
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct AppDetailSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(AppTypography.sectionLabel)
                .foregroundStyle(AppColors.secondaryText)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                content
            }
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(.black.opacity(0.04), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.04), radius: 10, y: 2)
        }
    }
}

struct AppDetailRow: View {
    let title: String
    let value: String
    var systemImage: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 24, height: 24)
            }
            Text(title)
                .font(AppTypography.rowLabel)
                .foregroundStyle(AppColors.secondaryText)
            Spacer(minLength: 16)
            Text(value.isEmpty ? "—" : value)
                .font(AppTypography.rowValue)
                .foregroundStyle(AppColors.text)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

struct AppDivider: View {
    var body: some View {
        Divider()
            .overlay(AppColors.chip)
            .padding(.leading, 14)
    }
}

struct AppInlineError: View {
    let message: String

    var body: some View {
        Text(message)
            .font(AppTypography.supporting)
            .foregroundStyle(AppColors.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(red: 1, green: 240 / 255, blue: 240 / 255))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }
}

struct AppSheetScaffold<Content: View>: View {
    let title: String
    let cancelTitle: String
    let actionTitle: String
    let isSaving: Bool
    let canSubmit: Bool
    let onCancel: () -> Void
    let onSubmit: () -> Void
    let content: Content

    init(
        title: String,
        cancelTitle: String = "Hủy",
        actionTitle: String,
        isSaving: Bool,
        canSubmit: Bool = true,
        onCancel: @escaping () -> Void,
        onSubmit: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.cancelTitle = cancelTitle
        self.actionTitle = actionTitle
        self.isSaving = isSaving
        self.canSubmit = canSubmit
        self.onCancel = onCancel
        self.onSubmit = onSubmit
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(AppColors.secondaryText.opacity(0.35))
                .frame(width: 38, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 10)

            ZStack {
                Text(title)
                    .font(AppTypography.navTitle)
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)

                HStack {
                    Button(cancelTitle, action: onCancel)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColors.secondaryText)
                        .disabled(isSaving)
                        .frame(minHeight: 44)
                    Spacer()
                    Button(action: onSubmit) {
                        if isSaving {
                            ProgressView()
                                .tint(AppColors.accent)
                        } else {
                            Text(actionTitle)
                                .font(.system(size: 14, weight: .black))
                        }
                    }
                    .foregroundStyle(AppColors.accent)
                    .disabled(isSaving || !canSubmit)
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 12) {
                    content
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .background(AppColors.background.ignoresSafeArea())
        .preferredColorScheme(.light)
    }
}

struct AppFormSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        AppDetailSection(title) {
            content
        }
    }
}

struct AppTextFieldRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var isDisabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.rowLabel)
                .foregroundStyle(AppColors.secondaryText)
            TextField(placeholder, text: $text, axis: axis)
                .font(AppTypography.rowValue)
                .foregroundStyle(AppColors.text)
                .textInputAutocapitalization(.never)
                .disabled(isDisabled)
                .lineLimit(axis == .vertical ? 3...6 : 1...1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isDisabled ? AppColors.chip.opacity(0.45) : Color.clear)
    }
}

struct AppSecureFieldRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.rowLabel)
                .foregroundStyle(AppColors.secondaryText)
            SecureField(placeholder, text: $text)
                .font(AppTypography.rowValue)
                .foregroundStyle(AppColors.text)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

struct AppPickerRow<Value: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: Value
    var isDisabled = false
    let content: Content

    init(title: String, selection: Binding<Value>, isDisabled: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self._selection = selection
        self.isDisabled = isDisabled
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(AppTypography.rowLabel)
                .foregroundStyle(AppColors.secondaryText)
            Spacer(minLength: 16)
            Picker("", selection: $selection) {
                content
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .font(AppTypography.rowValue)
            .tint(AppColors.accent)
            .disabled(isDisabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isDisabled ? AppColors.chip.opacity(0.45) : Color.clear)
    }
}

struct AppTopBar: View {
    let title: String
    var subtitle: String?
    var rightSystemImage: String = "bell"
    var rightAction: (() -> Void)?

    var body: some View {
        HStack {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.74))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)

            Spacer()

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColors.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(AppColors.secondaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                rightAction?()
            } label: {
                Image(systemName: rightSystemImage)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.text)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.74))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
            }
            .accessibilityLabel("Tác vụ")
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }
}

struct AppBottomBar: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.dashboard)
            tabButton(.tasks)

            Button {
                appState.activeSheet = .quickCreateTask
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.black)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.30), radius: 20, x: 0, y: 6)
            }
            .accessibilityLabel("Tạo mới")
            .frame(maxWidth: .infinity)

            tabButton(.calendar)
            tabButton(.profile)
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.black.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 8)
        .padding(.horizontal, 18)
    }

    private func tabButton(_ tab: MainTab) -> some View {
        Button {
            appState.selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.symbolName)
                    .font(.system(size: 19, weight: appState.selectedTab == tab ? .bold : .medium))
                Text(tab.title)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(appState.selectedTab == tab ? AppColors.accent : AppColors.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .accessibilityLabel(tab.title)
    }
}

struct LoadingStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AppColors.accent)
            Text(message)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(AppColors.secondaryText.opacity(0.7))
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppColors.text)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

struct ErrorStateView: View {
    let title: String
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(AppColors.danger)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppColors.danger)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.center)
            if let retry {
                Button("Thử lại", action: retry)
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.accent)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(red: 1, green: 240 / 255, blue: 240 / 255))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }
}

struct StatusDot: View {
    let status: TaskStatus

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .padding(10)
            .background(color.opacity(0.12))
            .clipShape(Circle())
    }

    private var color: Color {
        switch status {
        case .waiting: AppColors.warning
        case .doing: AppColors.accent
        case .done: AppColors.success
        }
    }
}

struct StatusBadge: View {
    let status: TaskStatus

    var body: some View {
        Text(status.rawValue)
            .font(.system(size: 11.5, weight: .black))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var color: Color {
        switch status {
        case .waiting: AppColors.warning
        case .doing: AppColors.accent
        case .done: AppColors.success
        }
    }
}

struct CategoryBadge: View {
    let category: ContentPlanCategory

    var body: some View {
        Text(category.rawValue)
            .font(.system(size: 11.5, weight: .black))
            .foregroundStyle(AppColors.text)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(AppColors.chip)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct InfoPill: View {
    let icon: String
    let text: String
    var tint: Color = AppColors.secondaryText

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 11.5, weight: .bold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
