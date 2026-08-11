import Foundation
import Supabase

@MainActor
final class NotificationRealtimeManager: ObservableObject {
    private let client: SupabaseClient?
    private var activeProfileId: String?
    private var channel: RealtimeChannelV2?
    private var subscriptionTask: Task<Void, Never>?

    init(config: AppConfig) {
        client = SupabaseClient(supabaseURL: config.supabaseURL, supabaseKey: config.supabaseAnonKey)
    }

    convenience init() {
        if let config = try? AppConfig.current() {
            self.init(config: config)
        } else {
            self.init(client: nil)
        }
    }

    private init(client: SupabaseClient?) {
        self.client = client
    }

    func start(profileId: UUID, notifications: NotificationsViewModel) {
        let profileIdString = profileId.uuidString.lowercased()
        guard activeProfileId != profileIdString else { return }
        stop()
        activeProfileId = profileIdString

        subscriptionTask = Task { [weak self, weak notifications] in
            await self?.subscribe(profileId: profileIdString, notifications: notifications)
        }
    }

    func stop() {
        activeProfileId = nil
        subscriptionTask?.cancel()
        subscriptionTask = nil

        if let channel {
            Task {
                await channel.unsubscribe()
            }
        }
        channel = nil
    }

    func reconnectIfNeeded(profileId: UUID?, notifications: NotificationsViewModel) {
        guard let profileId else {
            stop()
            return
        }
        start(profileId: profileId, notifications: notifications)
    }

    private func subscribe(profileId: String, notifications: NotificationsViewModel?) async {
        guard let client else { return }
        await client.realtimeV2.connect()
        let nextChannel = client.realtimeV2.channel("notifications-\(profileId)")
        channel = nextChannel

        let changes = nextChannel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "notifications",
            filter: .eq("recipient_id", value: profileId)
        )

        do {
            try await nextChannel.subscribeWithError()
        } catch {
            notifications?.handleRealtimeError("Realtime thông báo tạm thời gián đoạn.")
            return
        }

        for await action in changes {
            guard !Task.isCancelled, activeProfileId == profileId else { break }
            do {
                switch action {
                case .insert(let insert):
                    let row = try insert.decodeRecord(as: NotificationRealtimeRow.self, decoder: JSONDecoder())
                    notifications?.applyRealtimeInsert(row.domain)
                case .update(let update):
                    let row = try update.decodeRecord(as: NotificationRealtimeRow.self, decoder: JSONDecoder())
                    notifications?.applyRealtimeUpdate(row.domain)
                case .delete(let delete):
                    if let notificationId = delete.oldRecord["id"]?.stringValue {
                        notifications?.applyRealtimeDelete(notificationId: notificationId)
                    }
                }
            } catch {
                notifications?.handleRealtimeError("Không đọc được sự kiện thông báo realtime.")
            }
        }
    }
}

private struct NotificationRealtimeRow: Decodable {
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
