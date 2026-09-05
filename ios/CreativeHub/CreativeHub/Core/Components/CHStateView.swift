import SwiftUI

enum CHStateKind: Equatable {
    case loading
    case empty
    case error
    case offline
    case forbidden
    case sessionExpired

    var iconName: String {
        switch self {
        case .loading: "arrow.triangle.2.circlepath"
        case .empty: "tray"
        case .error: "exclamationmark.triangle"
        case .offline: "wifi.slash"
        case .forbidden: "lock"
        case .sessionExpired: "clock.arrow.circlepath"
        }
    }
}

struct CHStateView: View {
    var kind: CHStateKind
    var title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: CHSpacing.large) {
            ZStack {
                Circle()
                    .fill(CHColors.purple.opacity(0.09))
                    .frame(width: 62, height: 62)
                if kind == .loading {
                    ProgressView()
                        .tint(CHColors.purple)
                } else {
                    Image(systemName: kind.iconName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(CHColors.purple)
                }
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(CHTypography.headline)
                    .foregroundStyle(CHColors.ink)
                if let message {
                    Text(message)
                        .font(CHTypography.caption)
                        .foregroundStyle(CHColors.muted)
                        .multilineTextAlignment(.center)
                }
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(CHPrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(CHSpacing.screen)
    }
}

#Preview("State Loading") {
    CHStateView(kind: .loading, title: "Đang tải dữ liệu")
        .background(CHColors.background)
}

#Preview("State Empty") {
    CHStateView(kind: .empty, title: "Chưa có dữ liệu")
        .background(CHColors.background)
}
