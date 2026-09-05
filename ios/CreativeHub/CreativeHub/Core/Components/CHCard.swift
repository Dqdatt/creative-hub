import SwiftUI

struct CHCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: CHRadius.large, style: .continuous)
                    .fill(CHColors.card)
                    .stroke(Color.white.opacity(0.78), lineWidth: 1)
                    .shadow(color: CHShadow.cardColor, radius: 17, x: 0, y: 12)
            )
    }
}

#Preview("CHCard") {
    CHCard {
        Text("Card")
            .font(CHTypography.headline)
            .foregroundStyle(CHColors.ink)
            .frame(maxWidth: .infinity)
            .padding(24)
    }
    .padding()
    .background(CHColors.background)
}
