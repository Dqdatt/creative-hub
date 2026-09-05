import SwiftUI

enum CHToastKind: Equatable {
    case success
    case error
    case neutral

    var iconName: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .error: "xmark.octagon.fill"
        case .neutral: "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success: CHColors.green
        case .error: CHColors.red
        case .neutral: CHColors.purple
        }
    }
}

struct CHToastItem: Identifiable, Equatable {
    let id = UUID()
    var kind: CHToastKind
    var message: String
}

enum CHToastPresentation {
    static let showsDefaultIcon = false
    static let visibleBottomPaddingWithNavbar: CGFloat = 96
    static let visibleBottomPaddingWithoutNavbar: CGFloat = 20
    static let horizontalPadding: CGFloat = 14
    static let verticalPadding: CGFloat = 10
    static let transitionDuration: TimeInterval = 0.25
    static let hiddenOffsetY: CGFloat = 20
}

enum CHToastPlacement {
    static func bottomPadding(authentication: AuthenticationState, isBottomNavigationVisible: Bool) -> CGFloat {
        guard authentication == .authenticated else {
            return CHToastPresentation.visibleBottomPaddingWithoutNavbar
        }

        return isBottomNavigationVisible
            ? CHToastPresentation.visibleBottomPaddingWithNavbar
            : CHToastPresentation.visibleBottomPaddingWithoutNavbar
    }
}

struct CHToast: View {
    var item: CHToastItem

    var body: some View {
        Text(item.message)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, CHToastPresentation.horizontalPadding)
            .padding(.vertical, CHToastPresentation.verticalPadding)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(red: 24 / 255, green: 31 / 255, blue: 49 / 255).opacity(0.90))
                    .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            )
            .padding(.horizontal, 18)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("toast")
    }
}

#Preview("Toast") {
    VStack(spacing: 12) {
        CHToast(item: CHToastItem(kind: .success, message: "Đã cập nhật"))
        CHToast(item: CHToastItem(kind: .error, message: "Không thể tải dữ liệu"))
        CHToast(item: CHToastItem(kind: .neutral, message: "Đang đồng bộ"))
    }
    .padding()
    .background(CHColors.background)
}
