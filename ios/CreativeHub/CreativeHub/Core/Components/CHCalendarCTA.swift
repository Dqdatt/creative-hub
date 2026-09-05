import SwiftUI

struct CHCalendarCTA: View {
    var isActive: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x7A50FF), Color(hex: 0x5D75FF), Color(hex: 0x4E8CFF)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 58)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.96), lineWidth: 3)
                    )
                    .shadow(
                        color: Color(red: 73 / 255, green: 83 / 255, blue: 231 / 255).opacity(isActive ? 0.30 : 0.25),
                        radius: isActive ? 12.5 : 10.5,
                        y: isActive ? 12 : 10
                    )
                    .shadow(color: Color(red: 55 / 255, green: 66 / 255, blue: 115 / 255).opacity(0.09), radius: 3, y: 2)
                Image(systemName: "calendar")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(isActive ? 1.045 : 1)
            .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.30), value: isActive)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Lịch quay")
        .accessibilityIdentifier(MainDestination.calendar.navigationAccessibilityIdentifier)
    }
}

#Preview("CTA Default") {
    CHCalendarCTA(isActive: false) {}
        .padding()
        .background(CHColors.background)
}

#Preview("CTA Active") {
    CHCalendarCTA(isActive: true) {}
        .padding()
        .background(CHColors.background)
}
