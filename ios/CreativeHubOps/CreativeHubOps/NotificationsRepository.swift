import Foundation
import Supabase

protocol NotificationsRepositoryServing: Sendable {
    func fetchRecentNotifications(limit: Int) async throws -> [InternalNotification]
    func markRead(notificationId: String) async throws
    func markAllRead() async throws
}

final class NotificationsRepository: NotificationsRepositoryServing {
    private let client: SupabaseClient

    init(config: AppConfig) {
        client = SupabaseClient(supabaseURL: config.supabaseURL, supabaseKey: config.supabaseAnonKey)
    }

    convenience init() throws {
        try self.init(config: AppConfig.current())
    }

    func fetchRecentNotifications(limit: Int = 50) async throws -> [InternalNotification] {
        let normalizedLimit = min(max(limit, 1), 50)
        let rows: [NotificationRow] = try await client
            .from("notifications")
            .select("id,recipient_id,actor_id,type,title,body,entity_type,entity_id,action_url,event_key,read_at,created_at")
            .order("created_at", ascending: false)
            .limit(normalizedLimit)
            .execute()
            .value

        return rows.map(\.domain)
    }

    func markRead(notificationId: String) async throws {
        try await client
            .rpc("mark_notification_read", params: MarkNotificationReadParams(notificationId: notificationId))
            .execute()
    }

    func markAllRead() async throws {
        try await client
            .rpc("mark_all_notifications_read")
            .execute()
    }
}

private struct NotificationRow: Decodable {
    let id: String
    let recipientId: String
    let actorId: String?
    let type: String
    let title: String
    let body: String
    let entityType: String?
    let entityId: String?
    let actionURL: String?
    let eventKey: String?
    let readAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case recipientId = "recipient_id"
        case actorId = "actor_id"
        case type
        case title
        case body
        case entityType = "entity_type"
        case entityId = "entity_id"
        case actionURL = "action_url"
        case eventKey = "event_key"
        case readAt = "read_at"
        case createdAt = "created_at"
    }

    var domain: InternalNotification {
        InternalNotification(
            id: id,
            recipientId: recipientId,
            actorId: actorId,
            type: type,
            title: title,
            body: body,
            entityType: entityType,
            entityId: entityId,
            actionURL: actionURL,
            eventKey: eventKey,
            readAt: readAt,
            createdAt: createdAt
        )
    }
}

private struct MarkNotificationReadParams: Encodable {
    let notificationId: String

    enum CodingKeys: String, CodingKey {
        case notificationId = "p_notification_id"
    }
}

