import Foundation
import SwiftUI

enum ContentPlanCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case longForm = "Video dài"
    case shortReels = "Short/Reels"
    case livestream = "Livestream"
    case image = "Ảnh"
    case motion = "Motion"
    case ads = "Ads"

    var id: String { rawValue }

    init(rawValue: String?) {
        switch rawValue {
        case "Short/Reels": self = .shortReels
        case "Livestream": self = .livestream
        case "Ảnh": self = .image
        case "Motion": self = .motion
        case "Ads": self = .ads
        default: self = .longForm
        }
    }

    var tint: Color {
        switch self {
        case .longForm: CHColors.purple
        case .shortReels: CHColors.blue
        case .livestream: CHColors.green
        case .image: CHColors.orange
        case .motion: CHColors.blue
        case .ads: CHColors.red
        }
    }

    var softBackground: Color {
        switch self {
        case .longForm: Color(hex: 0xF0EAFF)
        case .shortReels: Color(hex: 0xE8F1FF)
        case .livestream: Color(hex: 0xE6F8EF)
        case .image: Color(hex: 0xFFF3DF)
        case .motion: Color(hex: 0xE8F1FF)
        case .ads: Color(hex: 0xFFECEE)
        }
    }

    var canCreateVideoTask: Bool {
        self == .longForm || self == .motion || self == .ads
    }
}

struct ContentPlanEditorOption: Identifiable, Equatable, Sendable {
    var id: String { editorCode }
    var editorCode: String
    var profileID: UUID
    var name: String
    var shortName: String
    var initials: String
    var colorHex: String
    var avatarURL: URL?
    var role: String
}

struct ContentPlanItem: Identifiable, Equatable, Sendable {
    var id: UUID
    var airDate: String
    var title: String
    var note: String
    var category: ContentPlanCategory
    var editorCode: String
    var editorProfileID: UUID?
    var editorDisplayName: String
    var link: String
    var linkedVideoTaskID: UUID?
    var linkedTaskStatus: String?

    var hasLinkedTask: Bool { linkedVideoTaskID != nil }
    var hasSafeLink: Bool { VideoTaskURLValidator.isSafeHTTPURL(link) }
    var normalizedLinkedTaskStatus: String? {
        linkedTaskStatus?.trimmingCharacters(in: .whitespacesAndNewlines).videoNilIfEmpty
    }
    var isLinkedTaskStarted: Bool {
        guard hasLinkedTask, let status = normalizedLinkedTaskStatus else { return false }
        return status != "Chờ"
    }
    var hasInconsistentMissingLinkedTask: Bool {
        category.canCreateVideoTask && !editorCode.isEmpty && !hasLinkedTask
    }
    var taskStateLabel: String {
        if !category.canCreateVideoTask {
            return "Không tạo Video Task"
        }
        if hasLinkedTask {
            guard let status = normalizedLinkedTaskStatus else { return "Đã có Task" }
            return "Task · \(status)"
        }
        if hasInconsistentMissingLinkedTask {
            return "Cần đồng bộ Task"
        }
        return "Chưa tạo Task"
    }
}

struct ContentPlanFormData: Equatable, Sendable {
    var airDate: String
    var title: String
    var note: String
    var category: ContentPlanCategory
    var editorCode: String
    var link: String

    static func createDefault(monthValue: String) -> ContentPlanFormData {
        ContentPlanFormData(
            airDate: "\(monthValue)-01",
            title: "",
            note: "",
            category: .longForm,
            editorCode: "",
            link: ""
        )
    }

    static func editing(_ item: ContentPlanItem) -> ContentPlanFormData {
        ContentPlanFormData(
            airDate: item.airDate,
            title: item.title,
            note: item.note,
            category: item.category,
            editorCode: item.editorCode,
            link: item.link
        )
    }
}

struct ContentPlanPermissions: Equatable, Sendable {
    var canCreate: Bool
    var canUpdate: Bool
    var canAssign: Bool
    var canDelete: Bool
    var isAdmin: Bool
    var currentProfileID: UUID?

    var canOpenEditor: Bool { canUpdate || canAssign || canDelete }
}

enum ContentPlanModuleMode: Equatable {
    case create
    case edit(ContentPlanItem)
    case assign(ContentPlanItem)
    case readOnly(ContentPlanItem)

    var title: String {
        switch self {
        case .create: "Thêm lịch air"
        case .edit: "Sửa lịch air"
        case .assign: "Phân công editor"
        case .readOnly: "Chi tiết Content"
        }
    }

    var item: ContentPlanItem? {
        switch self {
        case .create: nil
        case .edit(let item), .assign(let item), .readOnly(let item): item
        }
    }

    var isCreate: Bool {
        if case .create = self { return true }
        return false
    }

    static func resolve(item: ContentPlanItem, permissions: ContentPlanPermissions) -> ContentPlanModuleMode {
        if permissions.canUpdate { return .edit(item) }
        if permissions.canAssign { return .assign(item) }
        return .readOnly(item)
    }
}

struct ContentPlanFieldState: Equatable, Sendable {
    var canEditAirDate: Bool
    var canEditTitle: Bool
    var canEditNote: Bool
    var canEditCategory: Bool
    var canEditEditor: Bool
    var canEditLink: Bool
    var canSave: Bool

    static func resolve(mode: ContentPlanModuleMode?, permissions: ContentPlanPermissions) -> ContentPlanFieldState {
        guard let mode else { return .locked }
        switch mode {
        case .create:
            let canEditContent = permissions.canCreate
            return ContentPlanFieldState(
                canEditAirDate: canEditContent,
                canEditTitle: canEditContent,
                canEditNote: canEditContent,
                canEditCategory: canEditContent,
                canEditEditor: false,
                canEditLink: canEditContent,
                canSave: canEditContent
            )
        case .edit(let item):
            let canEditContent = permissions.canUpdate
            let canEditEditor = (permissions.canAssign || (permissions.isAdmin && permissions.canUpdate)) && !item.isLinkedTaskStarted
            return ContentPlanFieldState(
                canEditAirDate: canEditContent,
                canEditTitle: canEditContent,
                canEditNote: canEditContent,
                canEditCategory: canEditContent,
                canEditEditor: canEditEditor,
                canEditLink: canEditContent && !item.hasLinkedTask,
                canSave: canEditContent || canEditEditor
            )
        case .assign(let item):
            let canEditEditor = permissions.canAssign && !item.isLinkedTaskStarted
            return ContentPlanFieldState(
                canEditAirDate: false,
                canEditTitle: false,
                canEditNote: false,
                canEditCategory: false,
                canEditEditor: canEditEditor,
                canEditLink: false,
                canSave: canEditEditor
            )
        case .readOnly:
            return .locked
        }
    }

    static let locked = ContentPlanFieldState(
        canEditAirDate: false,
        canEditTitle: false,
        canEditNote: false,
        canEditCategory: false,
        canEditEditor: false,
        canEditLink: false,
        canSave: false
    )
}

enum ContentPlanFilterCategory: String, CaseIterable, Identifiable, Sendable {
    case all
    case longForm
    case shortReels
    case livestream
    case image
    case motion
    case ads

    var id: String { rawValue }

    var category: ContentPlanCategory? {
        switch self {
        case .all: nil
        case .longForm: .longForm
        case .shortReels: .shortReels
        case .livestream: .livestream
        case .image: .image
        case .motion: .motion
        case .ads: .ads
        }
    }

    var label: String {
        category?.rawValue ?? "Tất cả"
    }

    static let canonicalRailOrder: [ContentPlanFilterCategory] = [
        .all,
        .longForm,
        .motion,
        .ads,
        .shortReels,
        .livestream,
        .image
    ]
}

enum ContentPlanDateFormatter {
    static func monthValue(from date: Date) -> String {
        VideoTaskDateFormatter.monthValue(from: date)
    }

    static func monthRange(_ monthValue: String) -> (start: String, end: String) {
        VideoTaskDateFormatter.monthRange(monthValue)
    }

    static func isValidISODate(_ value: String) -> Bool {
        VideoTaskDateFormatter.isValidISODate(value)
    }

    static func display(_ value: String) -> String {
        VideoTaskDateFormatter.display(value)
    }
}

enum ContentPlanValidationError: LocalizedError, Equatable {
    case missingTitle
    case invalidDate
    case invalidLink
    case noteTooLong
    case mixedContentAndAssignment
    case missingEditor

    var errorDescription: String? {
        switch self {
        case .missingTitle: "Vui lòng nhập tên video."
        case .invalidDate: "Ngày Air không hợp lệ."
        case .invalidLink: "Link thành phẩm chưa hợp lệ."
        case .noteTooLong: "Ghi chú tối đa 2000 ký tự."
        case .mixedContentAndAssignment: "Vui lòng lưu nội dung trước, rồi phân công editor."
        case .missingEditor: "Vui lòng chọn editor."
        }
    }
}

enum ContentPlanRepositoryError: LocalizedError, Equatable {
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
