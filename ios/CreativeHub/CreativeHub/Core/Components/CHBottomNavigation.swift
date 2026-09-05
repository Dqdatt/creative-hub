import SwiftUI

struct CHBottomNavigation: View {
    @Binding var selected: MainDestination
    @Namespace private var indicatorNamespace

    var body: some View {
        HStack(alignment: .center, spacing: 1) {
            tab(.overview)
            tab(.video)

            VStack {
                CHCalendarCTA(isActive: selected == .calendar) {
                    select(.calendar)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .offset(y: -13)
            .accessibilityLabel("Lịch quay")
            .accessibilityIdentifier(MainDestination.calendar.navigationAccessibilityIdentifier)
            .animation(.timingCurve(0.22, 0.86, 0.28, 1, duration: 0.33), value: selected)

            tab(.content)
            tab(.members)
        }
        .padding(.horizontal, 4)
        .padding(.top, 5)
        .padding(.bottom, 4)
        .frame(height: 72)
        .background(
            CHGlassSurface(shape: RoundedRectangle(cornerRadius: 27, style: .continuous), variant: .tabBar)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private func tab(_ destination: MainDestination) -> some View {
        let isSelected = selected == destination
        return Button {
            select(destination)
        } label: {
            VStack(spacing: 1) {
                Image(systemName: destination.iconName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isSelected ? .white : CHColors.muted)
                    .scaleEffect(isSelected ? 1.10 : 0.93)
                    .opacity(isSelected ? 1 : 0.88)
                    .offset(y: isSelected ? -1 : 0)
                Text(destination.title)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(isSelected ? .white : CHColors.muted)
                    .opacity(isSelected ? 1 : 0.88)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(CHColors.primaryGradient)
                        .matchedGeometryEffect(id: "regular-tab-indicator", in: indicatorNamespace)
                        .shadow(color: Color(red: 77 / 255, green: 85 / 255, blue: 255 / 255).opacity(0.20), radius: 8, y: 7)
                        .transition(.opacity.combined(with: .scale(scale: 0.58)))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(destination.title)
        .accessibilityIdentifier(destination.navigationAccessibilityIdentifier)
    }

    private func select(_ destination: MainDestination) {
        let previous = selected
        let duration: TimeInterval = destination == .calendar ? 0.33 : (previous == .calendar ? 0.36 : 0.34)
        withAnimation(.timingCurve(0.22, 0.86, 0.28, 1, duration: duration)) {
            selected = destination
        }
    }
}

#Preview("Overview Selected") {
    CHBottomNavigation(selected: .constant(.overview))
        .background(CHColors.background)
}

#Preview("Video Selected") {
    CHBottomNavigation(selected: .constant(.video))
        .background(CHColors.background)
}

#Preview("Calendar Selected") {
    CHBottomNavigation(selected: .constant(.calendar))
        .background(CHColors.background)
}

#Preview("Content Selected") {
    CHBottomNavigation(selected: .constant(.content))
        .background(CHColors.background)
}

#Preview("Members Selected") {
    CHBottomNavigation(selected: .constant(.members))
        .background(CHColors.background)
}
