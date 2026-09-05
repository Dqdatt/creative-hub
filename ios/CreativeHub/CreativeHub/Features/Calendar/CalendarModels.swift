import Foundation
import SwiftUI

enum CalendarShootType: String, CaseIterable, Identifiable, Codable, Sendable {
    case livestream
    case lichquay
    case onset
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .livestream: "Livestream"
        case .lichquay: "Lịch quay"
        case .onset: "On set"
        case .other: "Khác"
        }
    }

    var tint: Color {
        switch self {
        case .livestream: Color(hex: 0xF59E0B)
        case .lichquay: CHColors.purple
        case .onset: Color(hex: 0x2563EB)
        case .other: Color(hex: 0x6B7280)
        }
    }

    var softBackground: Color {
        switch self {
        case .livestream: Color(hex: 0xFFF0DF)
        case .lichquay: Color(hex: 0xF0E8FF)
        case .onset: Color(hex: 0xE6F0FF)
        case .other: Color(hex: 0xEEF0F4)
        }
    }
}

enum CalendarShootFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case livestream
    case lichquay
    case onset
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "Tất cả"
        case .livestream: CalendarShootType.livestream.label
        case .lichquay: CalendarShootType.lichquay.label
        case .onset: CalendarShootType.onset.label
        case .other: CalendarShootType.other.label
        }
    }

    var type: CalendarShootType? {
        switch self {
        case .all: nil
        case .livestream: .livestream
        case .lichquay: .lichquay
        case .onset: .onset
        case .other: .other
        }
    }
}

struct CalendarShootEditor: Identifiable, Equatable, Sendable {
    var id: String { editorCode }
    var editorCode: String
    var profileID: UUID
    var label: String
}

struct CalendarEditorOption: Identifiable, Equatable, Sendable {
    var id: String { editorCode }
    var editorCode: String
    var profileID: UUID
    var name: String
    var shortName: String
    var initials: String
    var colorHex: String
    var avatarURL: URL?
}

enum CalendarEditorCrewLabelMapper {
    static func label(
        editorCode: String?,
        fullName: String? = nil,
        displayName: String? = nil,
        shortName: String? = nil
    ) -> String {
        let code = editorCode?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let codeLabelMap = ["dat": "ĐẠT", "hai": "HẢI", "minh": "MINH"]
        if let label = codeLabelMap[code] {
            return label
        }

        let source = firstNonEmpty([fullName, displayName, shortName, editorCode])
        let parts = source.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        return (parts.last ?? source).uppercased()
    }

    static func label(for option: CalendarEditorOption) -> String {
        label(editorCode: option.editorCode, fullName: option.name, shortName: option.shortName)
    }

    static func combine(editorLabels: [String], crew: String) -> String {
        (editorLabels + [crew.trimmingCharacters(in: .whitespacesAndNewlines)])
            .filter { !$0.isEmpty }
            .joined(separator: " - ")
    }

    private static func firstNonEmpty(_ values: [String?]) -> String {
        for value in values {
            let cleaned = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !cleaned.isEmpty {
                return cleaned
            }
        }
        return ""
    }
}

struct CalendarShoot: Identifiable, Equatable, Sendable {
    var id: UUID
    var date: Date
    var type: CalendarShootType
    var crew: String
    var editorCodes: [String]
    var editorProfileIDs: [UUID]
    var editorLabels: [String]
    var displayCrew: String
    var place: String
    var content: String
    var time: String
    var note: String
}

struct CalendarFormData: Equatable, Sendable {
    var date: String
    var type: CalendarShootType
    var time: String
    var place: String
    var editorCodes: [String]
    var crew: String
    var content: String
    var note: String

    static func createDefault(date: Date) -> CalendarFormData {
        CalendarFormData(
            date: CalendarDateFormatter.isoString(from: date),
            type: .lichquay,
            time: "ALL MORNING",
            place: "",
            editorCodes: [],
            crew: "",
            content: "",
            note: ""
        )
    }

    static func editing(_ shoot: CalendarShoot) -> CalendarFormData {
        CalendarFormData(
            date: CalendarDateFormatter.isoString(from: shoot.date),
            type: shoot.type,
            time: shoot.time,
            place: shoot.place,
            editorCodes: shoot.editorCodes,
            crew: shoot.crew,
            content: shoot.content,
            note: shoot.note
        )
    }
}

struct CalendarWeekDay: Identifiable, Equatable, Sendable {
    var id: String { isoDate }
    var date: Date
    var weekdayLabel: String
    var dayNumber: String
    var isSelected: Bool
    var isSunday: Bool
    var isoDate: String
}

struct CalendarDateRange: Equatable, Sendable {
    var startDate: String
    var endDate: String
}

enum CalendarDateFormatter {
    static let businessCalendar: Calendar = {
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = Locale(identifier: "vi_VN")
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 1
        return calendar
    }()

    private static let isoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = businessCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = businessCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func date(from value: String) -> Date? {
        isoFormatter.date(from: value)
    }

    static func isoString(from date: Date) -> String {
        isoFormatter.string(from: date)
    }

    static func monthLabel(from date: Date) -> String {
        "THÁNG \(businessCalendar.component(.month, from: date))"
    }

    static func weekdayLabel(from date: Date) -> String {
        switch businessCalendar.component(.weekday, from: date) {
        case 1: "CN"
        case 2: "THỨ 2"
        case 3: "THỨ 3"
        case 4: "THỨ 4"
        case 5: "THỨ 5"
        case 6: "THỨ 6"
        case 7: "THỨ 7"
        default: ""
        }
    }

    static func week(containing selectedDate: Date) -> [CalendarWeekDay] {
        let start = monday(containing: selectedDate)
        return (0..<7).compactMap { offset in
            guard let date = businessCalendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }
            let weekday = businessCalendar.component(.weekday, from: date)
            let selected = businessCalendar.isDate(date, inSameDayAs: selectedDate)
            return CalendarWeekDay(
                date: date,
                weekdayLabel: ["T2", "T3", "T4", "T5", "T6", "T7", "CN"][offset],
                dayNumber: String(businessCalendar.component(.day, from: date)),
                isSelected: selected,
                isSunday: weekday == 1,
                isoDate: isoString(from: date)
            )
        }
    }

    static func monday(containing date: Date) -> Date {
        let components = businessCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return businessCalendar.date(from: components) ?? date
    }

    static func monthRange(containing date: Date) -> CalendarDateRange {
        let components = businessCalendar.dateComponents([.year, .month], from: date)
        let start = businessCalendar.date(from: components) ?? date
        let interval = businessCalendar.dateInterval(of: .month, for: start)
        let end = interval?.end.addingTimeInterval(-1) ?? start
        return CalendarDateRange(startDate: isoString(from: start), endDate: isoString(from: end))
    }

    static func isValidISODate(_ value: String) -> Bool {
        guard let date = date(from: value) else { return false }
        return isoString(from: date) == value
    }
}

enum CalendarValidationError: LocalizedError, Equatable {
    case invalidDate
    case invalidType
    case missingPlace
    case missingContent

    var errorDescription: String? {
        switch self {
        case .invalidDate: "Ngày quay không hợp lệ."
        case .invalidType: "Loại lịch quay không hợp lệ."
        case .missingPlace: "Vui lòng nhập địa điểm lịch quay."
        case .missingContent: "Vui lòng nhập nội dung lịch quay."
        }
    }
}

enum CalendarRepositoryError: LocalizedError, Equatable {
    case configurationMissing
    case backend(String)

    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            "Kết nối dữ liệu chưa sẵn sàng. Vui lòng liên hệ quản trị viên."
        case .backend(let message):
            message
        }
    }
}

enum CalendarMutationKind: Equatable {
    case create
    case update(UUID)
    case delete(UUID)
}
