import SwiftUI

enum CHTimeScope: String, CaseIterable, Identifiable, Sendable {
    case day
    case week
    case month

    var id: String { rawValue }

    var label: String {
        switch self {
        case .day: "Ngày"
        case .week: "Tuần"
        case .month: "Tháng"
        }
    }

    static func fromEnvironment(_ value: String?) -> CHTimeScope? {
        switch value?.lowercased() {
        case "day": .day
        case "week": .week
        case "month": .month
        default: nil
        }
    }
}

struct CHTimeWeekDay: Identifiable, Equatable, Sendable {
    var id: String { isoDate }
    var date: Date
    var weekdayLabel: String
    var dayNumber: String
    var isSelected: Bool
    var isToday: Bool
    var isSunday: Bool
    var isoDate: String
}

struct CHTimeDateRange: Equatable, Sendable {
    var start: String
    var end: String
}

enum CHTimeNavigation {
    static let calendar: Calendar = {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 1
        return calendar
    }()

    private static let isoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func date(from value: String) -> Date? {
        isoFormatter.date(from: value)
    }

    static func isoString(from date: Date) -> String {
        isoFormatter.string(from: date)
    }

    static func monthValue(from date: Date) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 1970)-\(String(format: "%02d", components.month ?? 1))"
    }

    static func monthLabel(from monthValue: String) -> String {
        let parts = monthValue.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[1]) else {
            return "Tháng"
        }
        return "Tháng \(month), \(parts[0])"
    }

    static func dateForMonthValue(_ monthValue: String) -> Date {
        let parts = monthValue.split(separator: "-").map(String.init)
        let year = Int(parts.first ?? "") ?? calendar.component(.year, from: Date())
        let month = Int(parts.dropFirst().first ?? "") ?? calendar.component(.month, from: Date())
        return calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    static func monthRange(_ monthValue: String) -> CHTimeDateRange {
        let start = dateForMonthValue(monthValue)
        let interval = calendar.dateInterval(of: .month, for: start)
        let end = interval?.end.addingTimeInterval(-1) ?? start
        return CHTimeDateRange(start: isoString(from: start), end: isoString(from: end))
    }

    static func monday(containing date: Date) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let offset = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -offset, to: startOfDay) ?? startOfDay
    }

    static func weekRange(containing date: Date) -> CHTimeDateRange {
        let start = monday(containing: date)
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        return CHTimeDateRange(start: isoString(from: start), end: isoString(from: end))
    }

    static func range(for scope: CHTimeScope, selectedDate: Date, monthValue: String) -> CHTimeDateRange {
        switch scope {
        case .day:
            let iso = isoString(from: selectedDate)
            return CHTimeDateRange(start: iso, end: iso)
        case .week:
            return weekRange(containing: selectedDate)
        case .month:
            return monthRange(monthValue)
        }
    }

    static func monthValuesTouching(range: CHTimeDateRange) -> [String] {
        guard let start = date(from: range.start), let end = date(from: range.end) else {
            return []
        }
        var values: [String] = []
        var cursor = dateForMonthValue(monthValue(from: start))
        let final = dateForMonthValue(monthValue(from: end))
        while cursor <= final {
            values.append(monthValue(from: cursor))
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return values
    }

    static func weekDays(containing selectedDate: Date, today: Date = Date()) -> [CHTimeWeekDay] {
        let start = monday(containing: selectedDate)
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }
            let weekday = calendar.component(.weekday, from: date)
            return CHTimeWeekDay(
                date: date,
                weekdayLabel: ["T2", "T3", "T4", "T5", "T6", "T7", "CN"][offset],
                dayNumber: String(calendar.component(.day, from: date)),
                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                isToday: calendar.isDate(date, inSameDayAs: today),
                isSunday: weekday == 1,
                isoDate: isoString(from: date)
            )
        }
    }

    static func shiftedMonthValue(_ value: String, delta: Int) -> String {
        let date = dateForMonthValue(value)
        let shifted = calendar.date(byAdding: .month, value: delta, to: date) ?? date
        return monthValue(from: shifted)
    }
}

struct CHTimeScopeNavigator: View {
    var scope: CHTimeScope
    var monthLabel: String
    var weekDays: [CHTimeWeekDay]
    var accessibilityPrefix: String
    var onPrevious: () -> Void
    var onNext: () -> Void
    var onSelectScope: (CHTimeScope) -> Void
    var onSelectDay: (CHTimeWeekDay) -> Void

    @State private var isScopePopoverPresented = false

    var body: some View {
        VStack(spacing: 8) {
            monthHeader
            weekSelector
        }
        .overlay(alignment: .topTrailing) {
            if isScopePopoverPresented {
                scopePopoverLayer
            }
        }
        .zIndex(isScopePopoverPresented ? 20 : 0)
        .animation(.timingCurve(0.2, 0.75, 0.25, 1, duration: 0.20), value: scope)
        .animation(.easeOut(duration: 0.16), value: isScopePopoverPresented)
        .onDisappear {
            isScopePopoverPresented = false
        }
    }

    private var monthHeader: some View {
        HStack(spacing: 10) {
            Button(action: {
                dismissScopePopover()
                onPrevious()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(CHColors.muted)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("\(accessibilityPrefix).month.prev")

            Text(monthLabel)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(CHColors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("\(accessibilityPrefix).month.label")

            scopeMenu

            Button(action: {
                dismissScopePopover()
                onNext()
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(CHColors.muted)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("\(accessibilityPrefix).month.next")
        }
        .padding(.horizontal, 9)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.white.opacity(0.76))
                .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Color.white.opacity(0.72), lineWidth: 1))
                .shadow(color: CHShadow.softColor, radius: 8, y: 5)
        )
    }

    private var scopeMenu: some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) {
                isScopePopoverPresented.toggle()
            }
        } label: {
            HStack(spacing: 5) {
                Text(scope.label)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .heavy))
            }
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(CHColors.purple)
            .padding(.horizontal, 10)
            .frame(minWidth: 72, minHeight: 32)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.86))
                    .overlay(Capsule().stroke(CHColors.line, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("timeScopeButton")
        .accessibilityValue(scope.label)
    }

    private var scopePopoverLayer: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    dismissScopePopover()
                }

            scopePopover
                .padding(.top, 39)
                .padding(.trailing, 39)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scopePopover: some View {
        VStack(spacing: 0) {
            ForEach(CHTimeScope.allCases) { item in
                CHTimeScopePopoverRow(
                    item: item,
                    isSelected: scope == item,
                    accessibilityIdentifier: scopeOptionIdentifier(for: item),
                    onSelect: { selectScope(item) }
                )

                if item != CHTimeScope.allCases.last {
                    Divider()
                        .overlay(CHColors.line)
                        .padding(.leading, 40)
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.82), lineWidth: 1))
                .shadow(color: Color(red: 60 / 255, green: 70 / 255, blue: 110 / 255).opacity(0.18), radius: 18, y: 12)
        )
        .accessibilityIdentifier("timeScopePopover")
        .accessibilityValue(scope.label)
    }

    private var weekSelector: some View {
        VStack(spacing: 5) {
            HStack(spacing: 0) {
                ForEach(weekDays) { day in
                    Text(day.weekdayLabel)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(day.isSunday ? CHColors.red : Color(hex: 0x647089))
                        .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 0) {
                ForEach(weekDays) { day in
                    Button {
                        dismissScopePopover()
                        onSelectDay(day)
                    } label: {
                        VStack(spacing: 3) {
                            ZStack(alignment: .bottom) {
                                Text(day.dayNumber)
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundStyle(day.isSelected ? .white : (day.isSunday ? CHColors.red : CHColors.ink))
                                    .frame(width: 38, height: 38)
                                    .background(
                                        Circle()
                                            .fill(day.isSelected ? AnyShapeStyle(CHColors.primaryGradient) : AnyShapeStyle(Color.clear))
                                            .shadow(color: day.isSelected ? CHColors.purple.opacity(0.20) : Color.clear, radius: 10, y: 5)
                                    )
                                if day.isToday {
                                    Circle()
                                        .fill(day.isSelected ? Color.white : CHColors.green)
                                        .frame(width: 5, height: 5)
                                        .offset(y: -4)
                                }
                            }
                            Circle()
                                .fill(day.isSelected ? CHColors.purple : Color.clear)
                                .frame(width: 4, height: 4)
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(accessibilityPrefix).week.\(day.isoDate)")
                    .accessibilityValue(day.isSelected ? "selected" : (day.isToday ? "today" : ""))
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 7)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.80))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.70), lineWidth: 1))
                .shadow(color: CHShadow.softColor, radius: 9, y: 6)
        )
    }

    private func selectScope(_ item: CHTimeScope) {
        dismissScopePopover()
        onSelectScope(item)
    }

    private func dismissScopePopover() {
        guard isScopePopoverPresented else { return }
        withAnimation(.easeOut(duration: 0.14)) {
            isScopePopoverPresented = false
        }
    }

    private func scopeOptionIdentifier(for item: CHTimeScope) -> String {
        switch item {
        case .day: "timeScopeDay"
        case .week: "timeScopeWeek"
        case .month: "timeScopeMonth"
        }
    }
}

private struct CHTimeScopePopoverRow: View {
    var item: CHTimeScope
    var isSelected: Bool
    var accessibilityIdentifier: String
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(isSelected ? CHColors.purple : Color.clear)
                    .frame(width: 18)

                Text(item.label)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(isSelected ? CHColors.purple : CHColors.ink)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(width: 152, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(isSelected ? CHColors.purple.opacity(0.10) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityValue(isSelected ? "selected" : "")
    }
}
