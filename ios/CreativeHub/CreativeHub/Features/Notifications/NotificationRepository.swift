import Foundation
import Supabase

protocol NotificationDataProviding: Sendable {
    var usesProductionData: Bool { get }
    func fetchRecent(limit: Int) async throws -> [InternalNotification]
    func unreadCount() async throws -> Int
    func markRead(id: UUID) async throws -> Date
    func markAllRead() async throws -> Int
}

private extension String {
    var notificationNilIfEmpty: String? {
        let clean = trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }
}

enum NotificationRepositoryError: LocalizedError, Equatable {
    case configurationMissing
    case backend(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            "Kết nối dữ liệu chưa sẵn sàng."
        case .backend(let message):
            message
        case .invalidResponse:
            "Không nhận được dữ liệu thông báo hợp lệ."
        }
    }
}

struct NotificationSupabaseRepository: NotificationDataProviding {
    var usesProductionData: Bool { true }

    private let client: SupabaseClient?
    private let recentLimitRange = 1...50

    init(client: SupabaseClient? = SupabaseService.shared.client) {
        self.client = client
    }

    func fetchRecent(limit: Int) async throws -> [InternalNotification] {
        guard let client else { throw NotificationRepositoryError.configurationMissing }
        let normalizedLimit = min(max(limit, recentLimitRange.lowerBound), recentLimitRange.upperBound)
        let rows: [NotificationDTO] = try await client
            .from("notifications")
            .select("""
                id,
                recipient_id,
                actor_id,
                type,
                title,
                body,
                entity_type,
                entity_id,
                action_url,
                metadata,
                event_key,
                read_at,
                created_at
            """)
            .order("created_at", ascending: false)
            .limit(normalizedLimit)
            .execute()
            .value
        return rows.compactMap(\.notification)
    }

    func unreadCount() async throws -> Int {
        guard let client else { throw NotificationRepositoryError.configurationMissing }
        let response = try await client
            .from("notifications")
            .select("id", head: true, count: .exact)
            .is("read_at", value: nil)
            .execute()
        return response.count ?? 0
    }

    func markRead(id: UUID) async throws -> Date {
        guard let client else { throw NotificationRepositoryError.configurationMissing }
        let value: String = try await client
            .rpc("mark_notification_read", params: NotificationIDRPCParams(notificationID: id))
            .execute()
            .value
        guard let date = NotificationDateFormatter.date(from: value) else {
            throw NotificationRepositoryError.invalidResponse
        }
        return date
    }

    func markAllRead() async throws -> Int {
        guard let client else { throw NotificationRepositoryError.configurationMissing }
        let value: Int = try await client
            .rpc("mark_all_notifications_read")
            .execute()
            .value
        return value
    }
}

struct NotificationDTO: Decodable {
    var id: UUID
    var recipientID: UUID
    var actorID: UUID?
    var type: String
    var title: String?
    var body: String?
    var entityType: String?
    var entityID: UUID?
    var actionURL: String?
    var metadata: [String: JSONValue]?
    var eventKey: String?
    var readAt: String?
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case recipientID = "recipient_id"
        case actorID = "actor_id"
        case type
        case title
        case body
        case entityType = "entity_type"
        case entityID = "entity_id"
        case actionURL = "action_url"
        case metadata
        case eventKey = "event_key"
        case readAt = "read_at"
        case createdAt = "created_at"
    }

    var notification: InternalNotification? {
        guard let createdDate = NotificationDateFormatter.date(from: createdAt) else {
            return nil
        }
        return InternalNotification(
            id: id,
            recipientID: recipientID,
            actorID: actorID,
            rawType: type,
            type: NotificationSemanticType(rawValue: type),
            title: title?.notificationNilIfEmpty ?? "Thông báo",
            body: body?.notificationNilIfEmpty ?? "",
            entityType: entityType.flatMap(NotificationEntityType.init(rawValue:)),
            entityID: entityID,
            actionURL: actionURL,
            metadata: metadata ?? [:],
            eventKey: eventKey,
            readAt: NotificationDateFormatter.date(from: readAt),
            createdAt: createdDate
        )
    }
}

private struct NotificationIDRPCParams: Encodable {
    var pNotificationID: UUID

    init(notificationID: UUID) {
        pNotificationID = notificationID
    }

    enum CodingKeys: String, CodingKey {
        case pNotificationID = "p_notification_id"
    }
}
