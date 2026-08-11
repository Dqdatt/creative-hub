import Foundation

enum ContentPlanCategory: String, CaseIterable, Codable, Identifiable {
    case longVideo = "Video dài"
    case shortReels = "Short/Reels"
    case livestream = "Livestream"
    case image = "Ảnh"
    case motion = "Motion"
    case ads = "Ads"

    var id: String { rawValue }
}

enum TaskStatus: String, CaseIterable, Codable, Identifiable {
    case waiting = "Chờ"
    case doing = "Đang làm"
    case done = "Đã xong"

    var id: String { rawValue }
}

enum TaskPriority: String, Codable {
    case empty = ""
    case urgent = "Gấp"
}

enum LinkedTaskState: Equatable {
    case manual
    case waiting
    case doing
    case done

    init(task: VideoTask) {
        guard task.contentPlanId != nil else {
            self = .manual
            return
        }

        switch task.status {
        case .waiting:
            self = .waiting
        case .doing:
            self = .doing
        case .done:
            self = .done
        }
    }

    var isLinked: Bool {
        self != .manual
    }

    func canAccept(task: VideoTask, currentProfile: CurrentUserProfile?, editors: [EditorProfile]) -> Bool {
        guard self == .waiting,
              currentProfile?.can(.videoTasksUpdate) == true,
              let currentProfileId = currentProfile?.id.uuidString.lowercased()
        else {
            return false
        }

        return assignedProfileId(task: task, editors: editors) == currentProfileId
    }

    func canUpdateExecution(task: VideoTask, currentProfile: CurrentUserProfile?, editors: [EditorProfile]) -> Bool {
        guard self == .doing,
              currentProfile?.can(.videoTasksUpdate) == true,
              let currentProfileId = currentProfile?.id.uuidString.lowercased()
        else {
            return false
        }

        return assignedProfileId(task: task, editors: editors) == currentProfileId
    }

    func canComplete(task: VideoTask, currentProfile: CurrentUserProfile?, editors: [EditorProfile]) -> Bool {
        canUpdateExecution(task: task, currentProfile: currentProfile, editors: editors)
    }

    private func assignedProfileId(task: VideoTask, editors: [EditorProfile]) -> String? {
        guard let editorId = task.editorId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !editorId.isEmpty else {
            return nil
        }

        if VideoTaskFormData.looksLikeUUID(editorId) {
            return editorId
        }

        return editors.first { $0.id.lowercased() == editorId || $0.profileId.lowercased() == editorId }?.profileId.lowercased()
    }
}

enum TaskConstants {
    static let orderTeams = ["BRAND", "DIGITAL", "ECOM", "HR", "ISD", "IT", "CS", "GT", "PUR"]
    static let categories = ["Video dài", "Motion", "Ads"]
}

struct VideoTaskFormData: Equatable {
    var title = ""
    var status: TaskStatus = .waiting
    var editorCode = ""
    var orderTeam = TaskConstants.orderTeams[0]
    var category = "Video dài"
    var priority = ""
    var resizeRequirements = ""
    var receiveDate = ""
    var returnDate = ""
    var airDate = ""
    var resultLink = ""
    var notes = ""

    init() {}

    init(task: VideoTask, editors: [EditorProfile]) {
        title = task.title
        status = task.status
        editorCode = Self.editorCode(from: task.editorId, editors: editors)
        orderTeam = task.orderTeam.isEmpty ? TaskConstants.orderTeams[0] : task.orderTeam
        category = TaskConstants.categories.contains(task.category) ? task.category : "Video dài"
        priority = task.priority
        resizeRequirements = task.resizeRequirements
        receiveDate = task.receiveDate ?? ""
        returnDate = task.returnDate ?? ""
        airDate = task.airDate ?? ""
        resultLink = task.resultLink
        notes = task.notes
    }

    private static func editorCode(from value: String?, editors: [EditorProfile]) -> String {
        guard let value, !value.isEmpty else { return "" }
        return editors.first { $0.id == value || $0.profileId == value }?.id ?? value
    }

    static func looksLikeUUID(_ value: String) -> Bool {
        value.range(
            of: #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"#,
            options: .regularExpression
        ) != nil
    }
}

enum ShootType: String, CaseIterable, Codable, Identifiable {
    case lichquay
    case livestream
    case onset
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lichquay: "Lịch quay"
        case .livestream: "Livestream"
        case .onset: "On set"
        case .other: "Khác"
        }
    }
}

struct ShootFormData: Equatable {
    var date = AppDateFormatter.isoDate(from: Date())
    var type: ShootType = .lichquay
    var crew = ""
    var time = ""
    var place = ""
    var note = ""
    var editorIds: Set<String> = []

    init() {}

    init(shoot: ShootSchedule) {
        date = shoot.date
        type = ShootType(rawValue: shoot.type) ?? .other
        crew = shoot.crew
        time = shoot.timeSlot
        place = shoot.location
        note = shoot.note
        editorIds = Set(shoot.editorIds)
    }
}

struct ContentPlanFormData: Equatable {
    var airDate = AppDateFormatter.isoDate(from: Date())
    var title = ""
    var note = ""
    var category: ContentPlanCategory = .longVideo
    var editorCode = ""
    var link = ""

    init() {}

    init(item: ContentPlanItem) {
        airDate = item.airDate
        title = item.title
        note = item.note
        category = item.category
        editorCode = item.editorId ?? ""
        link = item.link
    }
}

struct LinkedTaskAcceptFormData: Equatable {
    var receiveDate = AppDateFormatter.isoDate(from: Date())
    var returnDate = ""

    init() {}

    init(task: VideoTask) {
        receiveDate = task.receiveDate ?? AppDateFormatter.isoDate(from: Date())
        returnDate = task.returnDate ?? ""
    }
}

struct LinkedTaskExecutionFormData: Equatable {
    var orderTeam = TaskConstants.orderTeams[0]
    var priority = ""
    var resizeRequirements = ""
    var receiveDate = ""
    var returnDate = ""
    var resultLink = ""

    init() {}

    init(task: VideoTask) {
        orderTeam = task.orderTeam.isEmpty ? TaskConstants.orderTeams[0] : task.orderTeam
        priority = task.priority
        resizeRequirements = task.resizeRequirements
        receiveDate = task.receiveDate ?? ""
        returnDate = task.returnDate ?? ""
        resultLink = task.resultLink
    }
}

struct VideoTask: Identifiable, Equatable {
    let id: String
    let sequence: Int?
    let title: String
    let resizeRequirements: String
    let editorId: String?
    let orderTeam: String
    let category: String
    let receiveDate: String?
    let returnDate: String?
    let airDate: String?
    let status: TaskStatus
    let priority: String
    let resultLink: String
    let notes: String
    let contentPlanId: String?
}

struct ContentPlanItem: Identifiable, Equatable {
    let id: String
    let airDate: String
    let title: String
    let note: String
    let category: ContentPlanCategory
    let editorId: String?
    let link: String
    let hasLinkedTask: Bool
}

struct ShootSchedule: Identifiable, Equatable {
    let id: String
    let date: String
    let type: String
    let crew: String
    let timeSlot: String
    let location: String
    let note: String
    let editorIds: [String]
    let editorProfileIds: [String]

    var typeLabel: String {
        (ShootType(rawValue: type) ?? .other).label
    }
}

struct EditorProfile: Identifiable, Equatable {
    let id: String
    let profileId: String
    let name: String
    let shortName: String
    let initial: String
    let colorHex: String
    let avatarURL: String
    let role: String
}

struct EditorWorkload: Identifiable, Equatable {
    let editor: EditorProfile
    let longVideoCount: Int
    let motionCount: Int
    let adsCount: Int
    let resizeCount: Int
    let shootCount: Int

    var id: String { editor.id }
    var total: Int { longVideoCount + motionCount + adsCount + shootCount }
}

struct DashboardSummary: Equatable {
    let tasks: [VideoTask]
    let shoots: [ShootSchedule]
    let editors: [EditorProfile]

    var totalTasks: Int { tasks.count }
    var completedTasks: Int { tasks.filter { $0.status == .done }.count }
    var inProgressTasks: Int { tasks.filter { $0.status == .doing }.count }
    var pendingTasks: Int { tasks.filter { $0.status == .waiting }.count }
    var progress: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }

    var upcomingTasks: [VideoTask] {
        tasks.filter { $0.status != .done }.prefix(4).map(\.self)
    }

    var upcomingShoots: [ShootSchedule] {
        shoots.prefix(4).map(\.self)
    }

    var editorWorkloads: [EditorWorkload] {
        editors.map { editor in
            let editorTasks = tasks.filter { task in
                task.editorId == editor.id || task.editorId == editor.profileId
            }
            let editorShoots = shoots.filter { shoot in
                shoot.type != "livestream" &&
                    (shoot.editorIds.contains(editor.id) || shoot.editorProfileIds.contains(editor.profileId))
            }

            return EditorWorkload(
                editor: editor,
                longVideoCount: editorTasks.filter { $0.category == "Video dài" }.count,
                motionCount: editorTasks.filter { $0.category == "Motion" }.count,
                adsCount: editorTasks.filter { $0.category == "Ads" }.count,
                resizeCount: editorTasks.reduce(0) { result, task in
                    result + task.resizeRequirements.split(separator: "&").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
                },
                shootCount: editorShoots.count
            )
        }
    }
}

struct MonthRange: Equatable {
    let value: String
    let startDate: String
    let endDate: String
}

enum AppDateFormatter {
    static func currentMonthRange(now: Date = Date(), calendar: Calendar = .current) -> MonthRange {
        let components = calendar.dateComponents([.year, .month], from: now)
        let start = calendar.date(from: components) ?? now
        let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? start

        return MonthRange(
            value: monthValue(from: start),
            startDate: isoDate(from: start),
            endDate: isoDate(from: end)
        )
    }

    static func monthRange(containing date: Date, calendar: Calendar = .current) -> MonthRange {
        currentMonthRange(now: date, calendar: calendar)
    }

    static func isoDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func monthValue(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    static func shortDisplay(_ isoDate: String?) -> String {
        guard let isoDate, isoDate.count >= 10 else { return "—" }
        let parts = isoDate.split(separator: "-")
        guard parts.count == 3 else { return isoDate }
        return "\(Int(parts[2]) ?? 0)/\(Int(parts[1]) ?? 0)"
    }

    static func displayDateTime(_ value: String?) -> String {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return "—"
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]

        guard let date = isoFormatter.date(from: value) ?? fallbackFormatter.date(from: value) else {
            return value.count >= 10 ? shortDisplay(String(value.prefix(10))) : value
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm · dd/MM/yyyy"
        return formatter.string(from: date)
    }

    static func normalizedDatabaseDate(_ value: String, label: String) throws -> String? {
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanValue.isEmpty else { return nil }

        if cleanValue.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
            guard isValidISODate(cleanValue) else {
                throw AppError.validation("\(label) không hợp lệ.")
            }
            return cleanValue
        }

        let parts = cleanValue.split(separator: "/")
        guard parts.count == 2 || parts.count == 3,
              let day = Int(parts[0]),
              let month = Int(parts[1])
        else {
            throw AppError.validation("\(label) chưa đúng định dạng. Dùng DD/MM hoặc YYYY-MM-DD.")
        }

        let rawYear = parts.count == 3 ? Int(parts[2]) : 2026
        guard let rawYear else {
            throw AppError.validation("\(label) chưa đúng định dạng. Dùng DD/MM hoặc YYYY-MM-DD.")
        }
        let year = rawYear < 100 ? 2000 + rawYear : rawYear
        let normalized = "\(year)-\(String(format: "%02d", month))-\(String(format: "%02d", day))"

        guard isValidISODate(normalized) else {
            throw AppError.validation("\(label) không hợp lệ.")
        }

        return normalized
    }

    static func normalizedOptionalHTTPURL(_ value: String) throws -> String? {
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanValue.isEmpty, cleanValue != "#" else { return nil }
        guard let url = URL(string: cleanValue), url.scheme == "http" || url.scheme == "https" else {
            throw AppError.validation("Link chưa đúng định dạng URL. Vui lòng dùng link bắt đầu bằng http:// hoặc https://.")
        }
        return cleanValue
    }

    static func normalizedRequiredHTTPURL(_ value: String) throws -> String {
        guard let url = try normalizedOptionalHTTPURL(value) else {
            throw AppError.validation("Link thành phẩm chưa hợp lệ.")
        }
        return url
    }

    private static func isValidISODate(_ value: String) -> Bool {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.date(from: value) != nil
    }
}
