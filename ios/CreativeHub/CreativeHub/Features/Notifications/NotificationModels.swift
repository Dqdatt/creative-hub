import Foundation
import SwiftUI

enum NotificationEntityType: String, CaseIterable, Sendable {
    case shoot
    case contentPlan = "content_plan"
    case videoTask = "video_task"
}

enum NotificationSemanticType: String, CaseIterable, Sendable {
    case shootCreated = "shoot_created"
    case shootUpdated = "shoot_updated"
    case shootCancelled = "shoot_cancelled"
    case shootMemberAdded = "shoot_member_added"
    case shootMemberRemoved = "shoot_member_removed"
    case contentPlanCreated = "content_plan_created"
    case contentPlanAssigned = "content_plan_assigned"
    case contentPlanReassigned = "content_plan_reassigned"
    case contentPlanDeleted = "content_plan_deleted"
    case videoTaskCreated = "video_task_created"
    case videoTaskAccepted = "video_task_accepted"
    case videoTaskExecutionUpdated = "video_task_execution_updated"
    case videoTaskCompleted = "video_task_completed"
    case videoTaskDeleted = "video_task_deleted"
    case unknown

    init(rawValue: String) {
        self = Self.allCases.first { $0.rawValue == rawValue } ?? .unknown
    }

    var iconName: String {
        switch self {
        case .shootCreated, .shootUpdated:
            "calendar"
        case .shootCancelled, .shootMemberRemoved, .contentPlanDeleted, .videoTaskDeleted:
            "trash"
        case .shootMemberAdded, .contentPlanAssigned, .contentPlanReassigned:
            "person.crop.circle.badge.checkmark"
        case .contentPlanCreated:
            "doc.badge.plus"
        case .videoTaskCreated:
            "play.rectangle"
        case .videoTaskAccepted, .videoTaskExecutionUpdated:
            "checklist"
        case .videoTaskCompleted:
            "checkmark.circle"
        case .unknown:
            "bell"
        }
    }

    var accentColor: Color {
        switch self {
        case .shootCreated, .shootUpdated:
            Color(hex: 0x2563EB)
        case .contentPlanCreated, .contentPlanAssigned, .contentPlanReassigned, .shootMemberAdded:
            Color(hex: 0x7C3AED)
        case .videoTaskCreated, .videoTaskAccepted, .videoTaskExecutionUpdated:
            Color(hex: 0x0891B2)
        case .videoTaskCompleted:
            Color(hex: 0x16A34A)
        case .shootCancelled, .shootMemberRemoved, .contentPlanDeleted, .videoTaskDeleted:
            Color(hex: 0xDC2626)
        case .unknown:
            CHColors.muted
        }
    }
}

struct InternalNotification: Identifiable, Equatable, Sendable {
    var id: UUID
    var recipientID: UUID
    var actorID: UUID?
    var rawType: String
    var type: NotificationSemanticType
    var title: String
    var body: String
    var entityType: NotificationEntityType?
    var entityID: UUID?
    var actionURL: String?
    var metadata: [String: JSONValue]
    var eventKey: String?
    var readAt: Date?
    var createdAt: Date

    var isUnread: Bool {
        readAt == nil
    }

    var relativeTimeText: String {
        NotificationDateFormatter.relative(createdAt, now: Date())
    }
}

enum JSONValue: Equatable, Sendable, Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }
}

enum NotificationDestination: Equatable, Sendable {
    case calendarShoot(UUID)
    case videoTask(UUID)
    case contentPlan(UUID)
    case members
    case overview
    case passive
    case unavailable
}

enum NotificationActionResolver {
    static func destination(for notification: InternalNotification) -> NotificationDestination {
        if let actionDestination = destination(from: notification.actionURL) {
            return actionDestination
        }

        guard let entityType = notification.entityType, let entityID = notification.entityID else {
            return .passive
        }

        switch entityType {
        case .shoot:
            return .calendarShoot(entityID)
        case .videoTask:
            return .videoTask(entityID)
        case .contentPlan:
            return .contentPlan(entityID)
        }
    }

    static func destination(from actionURL: String?) -> NotificationDestination? {
        guard let cleanValue = actionURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !cleanValue.isEmpty,
              cleanValue.hasPrefix("/"),
              !cleanValue.hasPrefix("//"),
              let components = URLComponents(string: cleanValue)
        else {
            return nil
        }

        let path = components.path
        let queryItems = components.queryItems ?? []

        func firstUUID(for names: [String]) -> UUID? {
            for name in names {
                if let value = queryItems.first(where: { $0.name == name })?.value,
                   let id = UUID(uuidString: value) {
                    return id
                }
            }
            return nil
        }

        switch path {
        case "/calendar":
            if let id = firstUUID(for: ["highlight", "shoot"]) {
                return .calendarShoot(id)
            }
            return .unavailable
        case "/tasks", "/video-thang":
            if let id = firstUUID(for: ["highlight", "task"]) {
                return .videoTask(id)
            }
            return .unavailable
        case "/content-plan":
            if let id = firstUUID(for: ["highlight", "item"]) {
                return .contentPlan(id)
            }
            return .unavailable
        case "/users":
            return .members
        case "/dashboard":
            return .overview
        default:
            return nil
        }
    }

    static func isSafeExternalLink(_ value: String?) -> Bool {
        guard let value, let components = URLComponents(string: value), let scheme = components.scheme else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }
}

enum NotificationDateFormatter {
    private static func fractionalISOFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private static func fallbackISOFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    static func date(from value: String?) -> Date? {
        guard let value else { return nil }
        return fractionalISOFormatter().date(from: value) ?? fallbackISOFormatter().date(from: value)
    }

    static func string(from date: Date) -> String {
        fractionalISOFormatter().string(from: date)
    }

    static func relative(_ date: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "Vừa xong" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) phút trước" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) giờ trước" }
        let days = hours / 24
        if days < 7 { return "\(days) ngày trước" }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
}
