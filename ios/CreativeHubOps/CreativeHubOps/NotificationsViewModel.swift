import Foundation

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published private(set) var notifications: [InternalNotification] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var repository: NotificationsRepositoryServing?
    private var loadGeneration = 0
    private var sessionGeneration = 0

    init(repository: NotificationsRepositoryServing? = nil) {
        self.repository = repository
    }

    var unreadCount: Int {
        notifications.filter(\.isUnread).count
    }

    func applyRealtimeInsert(_ notification: InternalNotification) {
        if notifications.contains(where: { $0.id == notification.id }) {
            applyRealtimeUpdate(notification)
            return
        }

        notifications.insert(notification, at: 0)
        notifications = Array(notifications.prefix(50))
    }

    func applyRealtimeUpdate(_ notification: InternalNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index] = notification
        } else {
            notifications.insert(notification, at: 0)
            notifications = Array(notifications.prefix(50))
        }
    }

    func applyRealtimeDelete(notificationId: String) {
        notifications.removeAll { $0.id == notificationId }
    }

    func handleRealtimeError(_ message: String) {
        errorMessage = message
        Task {
            await load(force: true)
        }
    }

    func clearForLogout() {
        sessionGeneration += 1
        loadGeneration += 1
        notifications = []
        isLoading = false
        errorMessage = nil
    }

    func load(force: Bool = false) async {
        guard force || (!isLoading && notifications.isEmpty) else { return }
        loadGeneration += 1
        let generation = loadGeneration
        let session = sessionGeneration

        isLoading = true
        errorMessage = nil
        defer {
            if isCurrentLoad(generation, session: session) {
                isLoading = false
            }
        }

        do {
            let repository = try makeRepository()
            let nextNotifications = try await repository.fetchRecentNotifications(limit: 50)
            guard isCurrentLoad(generation, session: session) else { return }
            notifications = nextNotifications
        } catch {
            guard isCurrentLoad(generation, session: session) else { return }
            notifications = []
            errorMessage = AppError.map(error, fallback: "Không thể tải thông báo.").localizedDescription
        }
    }

    func markRead(_ notification: InternalNotification) async {
        guard notification.isUnread else { return }
        let session = sessionGeneration
        do {
            let repository = try makeRepository()
            try await repository.markRead(notificationId: notification.id)
            guard isCurrentSession(session) else { return }
            await load(force: true)
        } catch {
            guard isCurrentSession(session) else { return }
            errorMessage = AppError.map(error, fallback: "Không thể cập nhật trạng thái thông báo.").localizedDescription
        }
    }

    func markAllRead() async {
        let session = sessionGeneration
        do {
            let repository = try makeRepository()
            try await repository.markAllRead()
            guard isCurrentSession(session) else { return }
            await load(force: true)
        } catch {
            guard isCurrentSession(session) else { return }
            errorMessage = AppError.map(error, fallback: "Không thể cập nhật trạng thái thông báo.").localizedDescription
        }
    }

    private func makeRepository() throws -> NotificationsRepositoryServing {
        if let repository { return repository }
        let repository = try NotificationsRepository()
        self.repository = repository
        return repository
    }

    private func isCurrentLoad(_ generation: Int, session: Int) -> Bool {
        generation == loadGeneration && isCurrentSession(session)
    }

    private func isCurrentSession(_ session: Int) -> Bool {
        session == sessionGeneration
    }
}
