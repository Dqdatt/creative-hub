import Foundation
import SwiftUI

enum VideoTaskStatus: String, CaseIterable, Identifiable, Codable, Sendable {
    case waiting = "Chờ"
    case inProgress = "Đang làm"
    case done = "Đã xong"

    var id: String { rawValue }

    var tint: Color {
        switch self {
        case .waiting: CHColors.orange
        case .inProgress: CHColors.blue
        case .done: CHColors.green
        }
    }

    var softBackground: Color {
        switch self {
        case .waiting: Color(hex: 0xFFF3DF)
        case .inProgress: Color(hex: 0xE8F1FF)
        case .done: Color(hex: 0xE6F8EF)
        }
    }
}

enum VideoTaskCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case longForm = "Video dài"
    case motion = "Motion"
    case ads = "Ads"

    var id: String { rawValue }

    init(rawValue: String?) {
        switch rawValue {
        case "Motion":
            self = .motion
        case "Ads":
            self = .ads
        default:
            self = .longForm
        }
    }

    var tint: Color {
        switch self {
        case .longForm: CHColors.purple
        case .motion: CHColors.blue
        case .ads: CHColors.red
        }
    }

    var softBackground: Color {
        switch self {
        case .longForm: Color(hex: 0xF0EAFF)
        case .motion: Color(hex: 0xE8F1FF)
        case .ads: Color(hex: 0xFFECEE)
        }
    }
}

enum VideoTaskPriority: String, CaseIterable, Identifiable, Codable, Sendable {
    case normal = ""
    case urgent = "Gấp"

    var id: String { rawValue.isEmpty ? "normal" : rawValue }
    var label: String { self == .normal ? "Bình thường" : rawValue }
}

enum VideoTaskFilterStatus: String, CaseIterable, Identifiable, Sendable {
    case all
    case done
    case inProgress
    case waiting

    var id: String { rawValue }

    var status: VideoTaskStatus? {
        switch self {
        case .all: nil
        case .done: .done
        case .inProgress: .inProgress
        case .waiting: .waiting
        }
    }

    var label: String {
        status?.rawValue ?? "Tất cả"
    }
}

struct VideoTaskEditorOption: Identifiable, Equatable, Sendable {
    var id: String { editorCode }
    var editorCode: String
    var profileID: UUID
    var name: String
    var shortName: String
    var initials: String
    var colorHex: String
    var avatarURL: URL?
}

struct VideoTask: Identifiable, Equatable, Sendable {
    var id: UUID
    var contentPlanID: UUID?
    var sequence: Int
    var title: String
    var resize: String
    var editorCode: String
    var editorProfileID: UUID?
    var editorDisplayName: String
    var orderTeam: String
    var category: VideoTaskCategory
    var receiveDate: String?
    var returnDate: String?
    var airDate: String?
    var status: VideoTaskStatus
    var priority: VideoTaskPriority
    var resultLink: String
    var note: String

    var isLinked: Bool { contentPlanID != nil }
    var isResultLinkActionable: Bool { VideoTaskURLValidator.isSafeHTTPURL(resultLink) }
}

struct VideoTaskFormData: Equatable, Sendable {
    var title: String
    var resize: String
    var editorCode: String
    var orderTeam: String
    var category: VideoTaskCategory
    var receiveDate: String
    var returnDate: String
    var airDate: String
    var status: VideoTaskStatus
    var priority: VideoTaskPriority
    var resultLink: String
    var note: String

    static func createDefault(editors: [VideoTaskEditorOption]) -> VideoTaskFormData {
        VideoTaskFormData(
            title: "",
            resize: "",
            editorCode: editors.first?.editorCode ?? "",
            orderTeam: VideoTaskConstants.orderTeams.first ?? "",
            category: .longForm,
            receiveDate: "",
            returnDate: "",
            airDate: "",
            status: .waiting,
            priority: .normal,
            resultLink: "",
            note: ""
        )
    }

    static func editing(_ task: VideoTask) -> VideoTaskFormData {
        VideoTaskFormData(
            title: task.title,
            resize: task.resize,
            editorCode: task.editorCode,
            orderTeam: task.orderTeam,
            category: task.category,
            receiveDate: task.receiveDate ?? "",
            returnDate: task.returnDate ?? "",
            airDate: task.airDate ?? "",
            status: task.status,
            priority: task.priority,
            resultLink: task.resultLink,
            note: task.note
        )
    }
}

struct VideoTaskExecutionData: Equatable, Sendable {
    var orderTeam: String
    var priority: VideoTaskPriority
    var resize: String
    var receiveDate: String
    var returnDate: String
    var resultLink: String
}

struct VideoTaskAcceptData: Equatable, Sendable {
    var receiveDate: String
    var returnDate: String
}

struct VideoTaskPermissions: Equatable, Sendable {
    var canCreate: Bool
    var canUpdate: Bool
    var canDelete: Bool
    var isAdmin: Bool
    var currentProfileID: UUID?
}

enum VideoTaskModuleMode: Equatable {
    case create
    case edit(VideoTask)
    case linkedAccept(VideoTask)
    case linkedExecution(VideoTask)
    case linkedPassiveDetail(VideoTask)
    case linkedAdminOverride(VideoTask)
    case readOnly(VideoTask)

    var title: String {
        switch self {
        case .create:
            return "Thêm Task mới"
        case .edit:
            return "Chỉnh sửa Task"
        case .linkedAccept:
            return "Nhận Task"
        case .linkedExecution:
            return "Hoàn thành Task"
        case .linkedPassiveDetail, .readOnly:
            return "Chi tiết Task"
        case .linkedAdminOverride:
            return "Chỉnh sửa Task"
        }
    }

    var task: VideoTask? {
        switch self {
        case .create: nil
        case .edit(let task),
             .linkedAccept(let task),
             .linkedExecution(let task),
             .linkedPassiveDetail(let task),
             .linkedAdminOverride(let task),
             .readOnly(let task):
            task
        }
    }

    var taskID: UUID? { task?.id }

    var isPassiveDetail: Bool {
        switch self {
        case .linkedPassiveDetail, .readOnly:
            true
        default:
            false
        }
    }

    static func resolve(task: VideoTask, permissions: VideoTaskPermissions) -> VideoTaskModuleMode {
        guard permissions.canUpdate else {
            return .readOnly(task)
        }
        guard task.isLinked else {
            return .edit(task)
        }
        if permissions.isAdmin {
            return .linkedAdminOverride(task)
        }
        let isAssignedCurrentEditor = task.editorProfileID == permissions.currentProfileID && permissions.currentProfileID != nil
        if task.status == .waiting && isAssignedCurrentEditor {
            return .linkedAccept(task)
        }
        if task.status == .inProgress && isAssignedCurrentEditor {
            return .linkedExecution(task)
        }
        return .linkedPassiveDetail(task)
    }
}

struct VideoTaskFieldState: Equatable, Sendable {
    var isLinkedTask: Bool
    var canEditTitle: Bool
    var canEditEditor: Bool
    var canEditStatus: Bool
    var canEditOrderTeam: Bool
    var canEditCategory: Bool
    var canEditPriority: Bool
    var canEditResize: Bool
    var canEditReceiveDate: Bool
    var canEditReturnDate: Bool
    var canEditAirDate: Bool
    var canEditResultLink: Bool
    var canEditNote: Bool
    var canAccept: Bool
    var canSaveExecution: Bool
    var canComplete: Bool
    var canUseGenericSave: Bool

    static func resolve(task: VideoTask?, permissions: VideoTaskPermissions, readOnly: Bool) -> VideoTaskFieldState {
        let isLinked = task?.isLinked == true
        if task == nil && !readOnly && permissions.canCreate {
            return VideoTaskFieldState(
                isLinkedTask: false,
                canEditTitle: true,
                canEditEditor: true,
                canEditStatus: true,
                canEditOrderTeam: true,
                canEditCategory: true,
                canEditPriority: true,
                canEditResize: true,
                canEditReceiveDate: true,
                canEditReturnDate: true,
                canEditAirDate: true,
                canEditResultLink: true,
                canEditNote: true,
                canAccept: false,
                canSaveExecution: false,
                canComplete: false,
                canUseGenericSave: true
            )
        }

        if readOnly || !permissions.canUpdate {
            return VideoTaskFieldState.allLocked(isLinkedTask: isLinked)
        }

        guard isLinked else {
            return VideoTaskFieldState(
                isLinkedTask: false,
                canEditTitle: true,
                canEditEditor: true,
                canEditStatus: true,
                canEditOrderTeam: true,
                canEditCategory: true,
                canEditPriority: true,
                canEditResize: true,
                canEditReceiveDate: true,
                canEditReturnDate: true,
                canEditAirDate: true,
                canEditResultLink: true,
                canEditNote: true,
                canAccept: false,
                canSaveExecution: false,
                canComplete: false,
                canUseGenericSave: true
            )
        }

        if permissions.isAdmin {
            return VideoTaskFieldState(
                isLinkedTask: true,
                canEditTitle: false,
                canEditEditor: false,
                canEditStatus: true,
                canEditOrderTeam: true,
                canEditCategory: false,
                canEditPriority: true,
                canEditResize: true,
                canEditReceiveDate: true,
                canEditReturnDate: true,
                canEditAirDate: false,
                canEditResultLink: true,
                canEditNote: false,
                canAccept: false,
                canSaveExecution: false,
                canComplete: false,
                canUseGenericSave: true
            )
        }

        let isAssignedCurrentEditor = task?.editorProfileID == permissions.currentProfileID && permissions.currentProfileID != nil
        let canAccept = task?.status == .waiting && permissions.canUpdate && isAssignedCurrentEditor
        let canComplete = task?.status == .inProgress && permissions.canUpdate && isAssignedCurrentEditor
        return VideoTaskFieldState(
            isLinkedTask: true,
            canEditTitle: false,
            canEditEditor: false,
            canEditStatus: false,
            canEditOrderTeam: canComplete,
            canEditCategory: false,
            canEditPriority: canComplete,
            canEditResize: canComplete,
            canEditReceiveDate: canAccept || canComplete,
            canEditReturnDate: canAccept || canComplete,
            canEditAirDate: false,
            canEditResultLink: canComplete,
            canEditNote: false,
            canAccept: canAccept,
            canSaveExecution: canComplete,
            canComplete: canComplete,
            canUseGenericSave: false
        )
    }

    private static func allLocked(isLinkedTask: Bool) -> VideoTaskFieldState {
        VideoTaskFieldState(
            isLinkedTask: isLinkedTask,
            canEditTitle: false,
            canEditEditor: false,
            canEditStatus: false,
            canEditOrderTeam: false,
            canEditCategory: false,
            canEditPriority: false,
            canEditResize: false,
            canEditReceiveDate: false,
            canEditReturnDate: false,
            canEditAirDate: false,
            canEditResultLink: false,
            canEditNote: false,
            canAccept: false,
            canSaveExecution: false,
            canComplete: false,
            canUseGenericSave: false
        )
    }
}

enum VideoTaskConstants {
    static let orderTeams = ["BRAND", "DIGITAL", "ECOM", "HR", "ISD", "IT", "CS", "GT", "PUR"]
}

enum VideoTaskURLValidator {
    static func normalizeRequired(_ value: String) throws -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isSafeHTTPURL(clean) else {
            throw VideoTaskValidationError.invalidResultLink
        }
        return clean
    }

    static func normalizeOptional(_ value: String) throws -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty || clean == "#" {
            return nil
        }
        return try normalizeRequired(clean)
    }

    static func isSafeHTTPURL(_ value: String) -> Bool {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean != "#", clean.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return false
        }
        guard let components = URLComponents(string: clean),
              let scheme = components.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              components.host?.isEmpty == false else {
            return false
        }
        return true
    }
}

enum VideoTaskDateFormatter {
    static let businessCalendar: Calendar = {
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = Locale(identifier: "vi_VN")
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 1
        return calendar
    }()

    private static let isoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = businessCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = businessCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func monthValue(from date: Date) -> String {
        let components = businessCalendar.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 1970)-\(String(format: "%02d", components.month ?? 1))"
    }

    static func monthRange(_ monthValue: String) -> (start: String, end: String) {
        let parts = monthValue.split(separator: "-").map(String.init)
        let year = Int(parts.first ?? "") ?? businessCalendar.component(.year, from: Date())
        let month = Int(parts.dropFirst().first ?? "") ?? businessCalendar.component(.month, from: Date())
        let start = businessCalendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
        let interval = businessCalendar.dateInterval(of: .month, for: start)
        let end = interval?.end.addingTimeInterval(-1) ?? start
        return (isoString(from: start), isoString(from: end))
    }

    static func date(from value: String) -> Date? {
        isoFormatter.date(from: value)
    }

    static func isoString(from date: Date) -> String {
        isoFormatter.string(from: date)
    }

    static func isValidISODate(_ value: String) -> Bool {
        guard value.isEmpty == false, let date = date(from: value) else {
            return false
        }
        return isoString(from: date) == value
    }

    static func display(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "-" }
        let parts = value.split(separator: "-")
        guard parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]) else {
            return value
        }
        return "\(day)/\(month)"
    }
}

enum VideoTaskValidationError: LocalizedError, Equatable {
    case missingTitle
    case invalidDate(String)
    case returnBeforeReceive
    case invalidResultLink
    case invalidEditor
    case invalidOrderTeam

    var errorDescription: String? {
        switch self {
        case .missingTitle:
            "Vui lòng nhập tên video."
        case .invalidDate(let label):
            "\(label) không hợp lệ."
        case .returnBeforeReceive:
            "Ngày trả phải sau hoặc bằng Ngày nhận."
        case .invalidResultLink:
            "Link thành phẩm chưa hợp lệ."
        case .invalidEditor:
            "Vui lòng chọn editor hợp lệ."
        case .invalidOrderTeam:
            "Team Order chưa hợp lệ."
        }
    }
}

enum VideoTaskRepositoryError: LocalizedError, Equatable {
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
