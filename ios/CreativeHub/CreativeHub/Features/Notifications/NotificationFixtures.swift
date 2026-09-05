import Foundation

actor NotificationFixtureRepository: NotificationDataProviding {
    enum Mode: String {
        case mixed
        case zeroUnread = "zero-unread"
        case empty
        case error
        case unavailable
        case markFailure = "mark-failure"
    }

    nonisolated var usesProductionData: Bool { false }

    private var mode: Mode
    private var notifications: [InternalNotification]

    init(mode: String = ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE9_NOTIFICATIONS_FIXTURE"] ?? "mixed") {
        self.mode = Mode(rawValue: mode) ?? .mixed
        switch self.mode {
        case .mixed, .markFailure:
            notifications = Self.seedNotifications
        case .zeroUnread:
            notifications = Self.seedNotifications.map { item in
                var copy = item
                copy.readAt = copy.readAt ?? Self.baseDate.addingTimeInterval(120)
                return copy
            }
        case .empty, .error:
            notifications = []
        case .unavailable:
            notifications = [Self.unavailableNotification]
        }
    }

    func fetchRecent(limit: Int) async throws -> [InternalNotification] {
        if mode == .error {
            throw NotificationRepositoryError.backend("Fixture Supabase notifications error")
        }
        return Array(notifications.sorted(by: NotificationSorter.areInIncreasingOrder).prefix(limit))
    }

    func unreadCount() async throws -> Int {
        if mode == .error {
            throw NotificationRepositoryError.backend("Fixture Supabase notifications count error")
        }
        return notifications.filter(\.isUnread).count
    }

    func markRead(id: UUID) async throws -> Date {
        if mode == .markFailure {
            throw NotificationRepositoryError.backend("Fixture RPC mark_notification_read failed")
        }
        let readDate = Self.baseDate.addingTimeInterval(300)
        notifications = notifications.map { notification in
            guard notification.id == id else { return notification }
            var copy = notification
            copy.readAt = readDate
            return copy
        }
        return readDate
    }

    func markAllRead() async throws -> Int {
        let readDate = Self.baseDate.addingTimeInterval(360)
        let unread = notifications.filter(\.isUnread).count
        notifications = notifications.map { notification in
            var copy = notification
            copy.readAt = copy.readAt ?? readDate
            return copy
        }
        return unread
    }

    static let currentRecipientID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let baseDate = NotificationDateFormatter.date(from: "2026-08-22T03:30:00.000Z")!

    static let seedNotifications: [InternalNotification] = [
        InternalNotification(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000901")!,
            recipientID: currentRecipientID,
            actorID: UUID(uuidString: "00000000-0000-0000-0000-000000000801"),
            rawType: "video_task_completed",
            type: .videoTaskCompleted,
            title: "Video Task đã hoàn thành",
            body: "CP: Motion BST phòng ngủ đã có link kết quả.",
            entityType: .videoTask,
            entityID: UUID(uuidString: "00000000-0000-0000-0000-000000000601")!,
            actionURL: "/tasks?highlight=00000000-0000-0000-0000-000000000601",
            metadata: [:],
            eventKey: "video_task_completed:00000000-0000-0000-0000-000000000601",
            readAt: nil,
            createdAt: baseDate
        ),
        InternalNotification(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000902")!,
            recipientID: currentRecipientID,
            actorID: UUID(uuidString: "00000000-0000-0000-0000-000000000802"),
            rawType: "content_plan_assigned",
            type: .contentPlanAssigned,
            title: "Bạn được phân công Content Plan",
            body: "Motion ưu đãi nệm tháng 8 cần chuẩn bị nội dung.",
            entityType: .contentPlan,
            entityID: UUID(uuidString: "00000000-0000-0000-0000-000000000702")!,
            actionURL: "/content-plan?highlight=00000000-0000-0000-0000-000000000702",
            metadata: [:],
            eventKey: "content_plan_assigned:00000000-0000-0000-0000-000000000702",
            readAt: nil,
            createdAt: baseDate.addingTimeInterval(-1_800)
        ),
        InternalNotification(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000903")!,
            recipientID: currentRecipientID,
            actorID: nil,
            rawType: "shoot_updated",
            type: .shootUpdated,
            title: "Lịch quay được cập nhật",
            body: "Buổi quay showroom Cần Thơ đã đổi khung giờ.",
            entityType: .shoot,
            entityID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            actionURL: "/calendar?highlight=00000000-0000-0000-0000-000000000002",
            metadata: [:],
            eventKey: "shoot_updated:00000000-0000-0000-0000-000000000002",
            readAt: baseDate.addingTimeInterval(-1_200),
            createdAt: baseDate.addingTimeInterval(-3_600)
        ),
        InternalNotification(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000904")!,
            recipientID: currentRecipientID,
            actorID: nil,
            rawType: "future_unknown_type",
            type: .unknown,
            title: "Cập nhật hệ thống",
            body: "Thông báo này không có điểm đến thao tác.",
            entityType: nil,
            entityID: nil,
            actionURL: nil,
            metadata: [:],
            eventKey: nil,
            readAt: nil,
            createdAt: baseDate.addingTimeInterval(-5_400)
        ),
        InternalNotification(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000905")!,
            recipientID: currentRecipientID,
            actorID: nil,
            rawType: "content_plan_deleted",
            type: .contentPlanDeleted,
            title: "Content Plan đã bị xóa",
            body: "Dòng kế hoạch cũ không còn khả dụng.",
            entityType: .contentPlan,
            entityID: UUID(uuidString: "00000000-0000-0000-0000-000000009999")!,
            actionURL: "/content-plan?highlight=00000000-0000-0000-0000-000000009999",
            metadata: [:],
            eventKey: "content_plan_deleted:00000000-0000-0000-0000-000000009999",
            readAt: nil,
            createdAt: baseDate.addingTimeInterval(-7_200)
        )
    ]

    static let unavailableNotification = seedNotifications[4]
}

enum NotificationProviderFactory {
    static func makeProvider() -> NotificationDataProviding {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE9_NOTIFICATIONS_FIXTURE"] {
            return NotificationFixtureRepository(mode: value)
        }
        #endif
        return NotificationSupabaseRepository()
    }
}
