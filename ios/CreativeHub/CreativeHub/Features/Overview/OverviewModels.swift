import Foundation
import SwiftUI

struct OverviewMonth: Equatable, Sendable {
    var year: Int
    var month: Int
    var calendar: Calendar

    init(date: Date = Date(), calendar: Calendar = .creativeHubBusiness) {
        let components = calendar.dateComponents([.year, .month], from: date)
        year = components.year ?? 2026
        month = components.month ?? 1
        self.calendar = calendar
    }

    init(year: Int, month: Int, calendar: Calendar = .creativeHubBusiness) {
        self.year = year
        self.month = month
        self.calendar = calendar
    }

    var monthValue: String {
        "\(year)-\(String(format: "%02d", month))"
    }

    var startDate: Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    var endDate: Date {
        calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startDate) ?? startDate
    }

    var endDateExclusive: Date {
        calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
    }

    var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: startDate)?.count ?? 31
    }

    var displayTitle: String {
        "Tháng \(month), \(year)"
    }

    var startISODate: String {
        Self.isoDateFormatter.string(from: startDate)
    }

    var endISODate: String {
        Self.isoDateFormatter.string(from: endDate)
    }

    var axisLabels: [String] {
        let finalDay = daysInMonth
        let raw = [1, 8, 15, 22, finalDay]
        return raw.map { String(format: "%02d", min($0, finalDay)) }
    }

    static func parseISODate(_ value: String?) -> Date? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return isoDateFormatter.date(from: value)
    }

    static func displayDateToDay(_ value: String?) -> Int? {
        guard let value else { return nil }
        if let date = parseISODate(value) {
            return Calendar.creativeHubBusiness.component(.day, from: date)
        }
        let parts = value.split(separator: "/")
        guard let first = parts.first, let day = Int(first) else { return nil }
        return day
    }

    static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .creativeHubBusiness
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.creativeHubBusiness.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

extension Calendar {
    static var creativeHubBusiness: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "vi_VN")
        calendar.timeZone = .current
        return calendar
    }
}

enum OverviewLoadState: Equatable {
    case idle
    case loading
    case loaded(OverviewDashboard)
    case failed(String, stale: OverviewDashboard?)
}

struct OverviewDashboard: Equatable, Sendable {
    var month: OverviewMonth
    var totalVideos: Int
    var completedVideos: Int
    var shootCount: Int
    var teamOrders: [OverviewTeamOrder]
    var editorWorkload: [OverviewEditorWorkload]
    var chartPoints: [OverviewChartPoint]
    var shootLoadTrack: OverviewTrackSemantics

    var remainingVideos: Int {
        max(0, totalVideos - completedVideos)
    }

    var completionRatio: Double {
        guard totalVideos > 0 else { return 0 }
        return Double(completedVideos) / Double(totalVideos)
    }

    var completionPercent: Int {
        Int((completionRatio * 100).rounded())
    }

    var isZeroData: Bool {
        totalVideos == 0 && shootCount == 0 && editorWorkload.isEmpty && teamOrders.allSatisfy { $0.count == 0 }
    }
}

struct OverviewTeamOrder: Identifiable, Equatable, Sendable {
    var id: String { label }
    var label: String
    var count: Int

    func segmentRatio(total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
}

struct OverviewEditorWorkload: Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var shortName: String
    var initials: String
    var avatarURL: URL?
    var colorHex: String
    var taskCount: Int
    var buckets: [Int]
}

struct OverviewChartPoint: Identifiable, Equatable, Sendable {
    var id: Int { day }
    var day: Int
    var value: Int
}

enum OverviewTrackSemantics: Equatable, Sendable {
    case ratio(Double)
    case neutral

    var fillRatio: Double? {
        switch self {
        case .ratio(let ratio):
            return max(0, min(1, ratio))
        case .neutral:
            return nil
        }
    }
}

struct OverviewRawData: Equatable, Sendable {
    var tasks: [OverviewTaskRow]
    var shoots: [OverviewShootRow]
    var editors: [OverviewEditorRow]
}

struct OverviewTaskRow: Equatable, Sendable {
    var id: String
    var title: String
    var orderTeam: String
    var category: String
    var status: String
    var resizeRequirements: String
    var receiveDate: String?
    var returnDate: String?
    var airDate: String?
    var linkedAirDate: String?
    var resultLink: String
    var editorCode: String
    var editorProfileID: String?

    var effectiveAirDate: String? {
        Self.nonEmpty(linkedAirDate) ?? Self.nonEmpty(airDate)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

struct OverviewShootRow: Equatable, Sendable {
    var id: String
    var shootDate: String
    var type: String
    var editorCodes: [String]
    var editorProfileIDs: [String]
}

struct OverviewEditorRow: Equatable, Sendable {
    var id: String
    var editorCode: String
    var name: String
    var shortName: String
    var initials: String
    var avatarURL: URL?
    var colorHex: String
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}
