import Foundation

struct InternalNotification: Identifiable, Equatable {
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

    var isUnread: Bool {
        readAt == nil
    }
}

