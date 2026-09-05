import Foundation

enum NotificationLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

enum NotificationSorter {
    static func areInIncreasingOrder(_ lhs: InternalNotification, _ rhs: InternalNotification) -> Bool {
        if lhs.createdAt == rhs.createdAt {
            return lhs.id.uuidString > rhs.id.uuidString
        }
        return lhs.createdAt > rhs.createdAt
    }
}

@MainActor
final class NotificationViewModel: ObservableObject {
    @Published private(set) var loadState: NotificationLoadState = .idle
    @Published private(set) var notifications: [InternalNotification] = []
    @Published private(set) var unreadCount = 0
    @Published var mutationError: String?
    @Published var isMarkingAll = false
    @Published var openedNotificationID: UUID?
    @Published var safeNotice: String?

    let provider: NotificationDataProviding
    private let limit: Int
    private var pendingReadIDs: Set<UUID> = []

    init(provider: NotificationDataProviding = NotificationProviderFactory.makeProvider(), limit: Int = 15) {
        self.provider = provider
        self.limit = limit
    }

    var hasUnread: Bool {
        unreadCount > 0
    }

    func loadIfNeeded() async {
        if case .idle = loadState {
            await load()
        }
    }

    func load(silent: Bool = false) async {
        if !silent {
            loadState = .loading
        }
        mutationError = nil
        do {
            async let nextNotifications = provider.fetchRecent(limit: limit)
            async let nextUnreadCount = provider.unreadCount()
            notifications = try await nextNotifications.sorted(by: NotificationSorter.areInIncreasingOrder)
            unreadCount = max(0, try await nextUnreadCount)
            loadState = .loaded
        } catch {
            if AsyncCancellation.isCancellation(error) {
                return
            }
            if !silent {
                notifications = []
                unreadCount = 0
                loadState = .failed(Self.safeMessage(for: error, fallback: "Vui lòng thử lại."))
            }
        }
    }

    func refresh() async -> String? {
        mutationError = nil
        do {
            async let nextNotifications = provider.fetchRecent(limit: limit)
            async let nextUnreadCount = provider.unreadCount()
            notifications = try await nextNotifications.sorted(by: NotificationSorter.areInIncreasingOrder)
            unreadCount = max(0, try await nextUnreadCount)
            loadState = .loaded
            return nil
        } catch {
            if AsyncCancellation.isCancellation(error) {
                return nil
            }
            let message = Self.safeMessage(for: error, fallback: "Không thể tải thông báo mới.")
            if notifications.isEmpty {
                loadState = .failed(message)
            }
            return message
        }
    }

    func refreshUnreadIndicator() async {
        do {
            unreadCount = max(0, try await provider.unreadCount())
        } catch {
            if AsyncCancellation.isCancellation(error) {
                return
            }
            if provider.usesProductionData {
                unreadCount = 0
            }
        }
    }

    func markRead(_ notification: InternalNotification) async -> Bool {
        if pendingReadIDs.contains(notification.id) {
            return true
        }
        guard notification.isUnread else {
            openedNotificationID = notification.id
            return true
        }

        pendingReadIDs.insert(notification.id)
        mutationError = nil
        let optimisticReadAt = Date()
        applyRead(id: notification.id, readAt: optimisticReadAt)
        unreadCount = max(0, unreadCount - 1)

        do {
            let readAt = try await provider.markRead(id: notification.id)
            applyRead(id: notification.id, readAt: readAt)
            openedNotificationID = notification.id
            await load(silent: true)
            pendingReadIDs.remove(notification.id)
            return true
        } catch {
            let safeError = Self.safeMessage(for: error, fallback: "Không thể cập nhật trạng thái thông báo.")
            await load(silent: true)
            mutationError = safeError
            pendingReadIDs.remove(notification.id)
            return false
        }
    }

    func markAllRead() async -> Bool {
        guard unreadCount > 0, !isMarkingAll else {
            return true
        }
        mutationError = nil
        isMarkingAll = true
        defer { isMarkingAll = false }

        do {
            _ = try await provider.markAllRead()
            let readAt = Date()
            notifications = notifications.map { notification in
                var copy = notification
                copy.readAt = copy.readAt ?? readAt
                return copy
            }
            unreadCount = 0
            await load(silent: true)
            return true
        } catch {
            let safeError = Self.safeMessage(for: error, fallback: "Không thể cập nhật trạng thái thông báo.")
            await load(silent: true)
            mutationError = safeError
            return false
        }
    }

    func showSafeNotice(_ message: String) {
        safeNotice = message
    }

    func clearSafeNotice() {
        safeNotice = nil
    }

    static func safeMessage(for error: Error, fallback: String) -> String {
        if AsyncCancellation.isCancellation(error) {
            return fallback
        }
        let raw = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let unsafeMarkers = ["fixture", "backend", "rpc", "sql", "supabase", "postgrest", "uuid", "row-level"]
        if raw.isEmpty || unsafeMarkers.contains(where: { raw.localizedCaseInsensitiveContains($0) }) {
            return fallback
        }
        return raw
    }

    private func applyRead(id: UUID, readAt: Date) {
        notifications = notifications.map { notification in
            guard notification.id == id else { return notification }
            var copy = notification
            copy.readAt = readAt
            return copy
        }
    }
}
