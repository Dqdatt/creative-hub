import SwiftUI

struct CHPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CHTypography.label)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(CHColors.primaryGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color(red: 80 / 255, green: 92 / 255, blue: 255 / 255).opacity(0.20), radius: 9, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct CHSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CHTypography.label)
            .foregroundStyle(CHColors.ink)
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(CHColors.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(CHColors.line))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct CHDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CHTypography.label)
            .foregroundStyle(Color(hex: 0xB42318))
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(Color(hex: 0xFEE4E2), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: 0xFDA29B)))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
