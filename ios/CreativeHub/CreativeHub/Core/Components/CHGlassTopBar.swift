import SwiftUI

struct CHGlassTopBar: View {
    enum Mode: Equatable {
        case overview(displayName: String)
        case main(title: String)
        case secondary(title: String)
        case module(title: String)
    }

    var mode: Mode
    var hasUnreadNotifications = true
    var onLeading: () -> Void = {}
    var onNotifications: () -> Void = {}
    var onAvatar: () -> Void = {}

    var body: some View {
        topBarContent
            .padding(4)
            .frame(height: 48)
            .background(
                CHGlassSurface(shape: Capsule(style: .continuous), variant: .topBar)
            )
    }

    @ViewBuilder
    private var topBarContent: some View {
        switch mode {
        case .overview:
            HStack(spacing: 0) {
                title
                    .frame(maxWidth: .infinity, alignment: .leading)

                actions
                    .frame(width: 68, alignment: .trailing)
            }
        case .main, .secondary, .module:
            HStack(spacing: 8) {
                leading
                    .frame(width: 68, alignment: .leading)

                title
                    .frame(maxWidth: .infinity)

                actions
                    .frame(width: 68, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private var leading: some View {
        switch mode {
        case .overview:
            Color.clear
        case .main:
            Button(action: onLeading) {
                Image(systemName: "ellipsis")
            }
            .buttonStyle(GlassCircleButtonStyle())
            .accessibilityLabel("Bộ lọc")
            .accessibilityIdentifier("topbar.more")
        case .secondary, .module:
            Button(action: onLeading) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(GlassCircleButtonStyle())
            .accessibilityLabel("Quay lại")
            .accessibilityIdentifier(backButtonIdentifier)
        }
    }

    private var backButtonIdentifier: String {
        switch mode {
        case .module:
            "module.back"
        case .secondary:
            "topbar.back"
        case .overview, .main:
            "topbar.back"
        }
    }

    @ViewBuilder
    private var title: some View {
        switch mode {
        case .overview(let displayName):
            VStack(alignment: .leading, spacing: 0) {
                Text("Xin chào")
                    .font(CHTypography.micro)
                    .foregroundStyle(Color(hex: 0x7C88A0))
                Text(displayName)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Color(hex: 0x202737))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 14)
        case .main(let title), .secondary(let title), .module(let title):
            Text(title)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(CHColors.ink)
                .lineLimit(1)
                .accessibilityIdentifier("topbar.title")
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch mode {
        case .secondary, .module:
            Color.clear
        case .overview, .main:
            HStack(spacing: 4) {
                Button(action: onNotifications) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                        if hasUnreadNotifications {
                            Circle()
                                .fill(Color(hex: 0xFF4F67))
                                .frame(width: 7, height: 7)
                                .offset(x: 3, y: -3)
                                .accessibilityIdentifier("topbar.notifications.unread-dot")
                        }
                    }
                }
                .buttonStyle(GlassCircleButtonStyle())
                .accessibilityLabel("Thông báo")
                .accessibilityValue(hasUnreadNotifications ? "Có thông báo chưa đọc" : "Không có thông báo chưa đọc")
                .accessibilityIdentifier("topbar.notifications")

                Button(action: onAvatar) {
                    CHAvatar(initials: "CH", imageName: "Logo", size: 24)
                }
                .buttonStyle(GlassCircleButtonStyle())
                .accessibilityLabel("Hồ sơ")
                .accessibilityIdentifier("topbar.profile")
            }
        }
    }
}

private struct GlassCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(CHColors.ink)
            .frame(width: 30, height: 30)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.88),
                                Color(red: 243 / 255, green: 246 / 255, blue: 252 / 255).opacity(0.60)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(Circle().stroke(Color(red: 123 / 255, green: 136 / 255, blue: 170 / 255).opacity(0.12)))
                    .shadow(color: Color(red: 73 / 255, green: 86 / 255, blue: 128 / 255).opacity(0.06), radius: 8, y: 5)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

struct CHGlassSurface<S: InsettableShape>: View {
    enum Variant {
        case topBar
        case tabBar
    }

    var shape: S
    var variant: Variant

    var body: some View {
        ZStack {
            shape
                .fill(.ultraThinMaterial)
                .opacity(materialOpacity)

            shape
                .fill(glassGradient)

            shape
                .stroke(Color.white.opacity(borderOpacity), lineWidth: 1)
        }
        .clipShape(shape)
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
        .overlay(
            shape
                .stroke(Color.white.opacity(innerHighlightOpacity), lineWidth: 1)
                .blendMode(.screen)
        )
    }

    private var glassGradient: LinearGradient {
        switch variant {
        case .topBar:
            LinearGradient(
                colors: [
                    Color.white.opacity(0.84),
                    Color.white.opacity(0.56)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .tabBar:
            LinearGradient(
                colors: [
                    Color.white.opacity(0.78),
                    Color(red: 247 / 255, green: 249 / 255, blue: 255 / 255).opacity(0.54)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var materialOpacity: Double {
        switch variant {
        case .topBar: 0.16
        case .tabBar: 0.18
        }
    }

    private var borderOpacity: Double {
        switch variant {
        case .topBar: 0.86
        case .tabBar: 0.90
        }
    }

    private var innerHighlightOpacity: Double {
        switch variant {
        case .topBar: 0.95
        case .tabBar: 0.96
        }
    }

    private var shadowColor: Color {
        switch variant {
        case .topBar:
            Color(red: 62 / 255, green: 74 / 255, blue: 118 / 255).opacity(0.09)
        case .tabBar:
            Color(red: 54 / 255, green: 65 / 255, blue: 110 / 255).opacity(0.14)
        }
    }

    private var shadowRadius: CGFloat {
        switch variant {
        case .topBar: 17
        case .tabBar: 18
        }
    }

    private var shadowY: CGFloat {
        switch variant {
        case .topBar: 11
        case .tabBar: 16
        }
    }
}

#Preview("Overview Topbar") {
    CHGlassTopBar(mode: .overview(displayName: "Creative Team"))
        .padding()
        .background(CHColors.background)
}

#Preview("Main Topbar") {
    CHGlassTopBar(mode: .main(title: "Video"))
        .padding()
        .background(CHColors.background)
}
