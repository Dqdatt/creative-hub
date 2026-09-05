import Foundation
import Supabase

protocol VideoTaskDataProviding: Sendable {
    var usesProductionData: Bool { get }
    func fetchTasks(monthValue: String) async throws -> [VideoTask]
    func fetchEditorOptions() async throws -> [VideoTaskEditorOption]
    func createTask(_ data: VideoTaskFormData, userID: UUID?) async throws
    func updateTask(id: UUID, data: VideoTaskFormData, previousTask: VideoTask, userID: UUID?, allowLinkedOverride: Bool) async throws
    func deleteTask(_ task: VideoTask, userID: UUID?) async throws
    func acceptLinkedTask(id: UUID, data: VideoTaskAcceptData) async throws
    func updateLinkedExecution(id: UUID, data: VideoTaskExecutionData) async throws
    func completeLinkedTask(id: UUID, resultLink: String) async throws
}

struct VideoTaskSupabaseRepository: VideoTaskDataProviding {
    var usesProductionData: Bool { true }

    private let client: SupabaseClient?
    private let pageSize = 1_000

    init(client: SupabaseClient? = SupabaseService.shared.client) {
        self.client = client
    }

    func fetchTasks(monthValue: String) async throws -> [VideoTask] {
        guard let client else { throw VideoTaskRepositoryError.configurationMissing }
        var rows: [VideoTaskDTO] = []
        var offset = 0

        while true {
            let page: [VideoTaskDTO] = try await client
                .from("video_tasks")
                .select(Self.taskSelect)
                .order("air_date", ascending: true, nullsFirst: false)
                .order("stt", ascending: true)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value
            rows.append(contentsOf: page)
            guard page.count == pageSize else { break }
            offset += pageSize
        }

        let range = VideoTaskDateFormatter.monthRange(monthValue)
        return rows
            .filter { row in
                guard let airDate = row.effectiveAirDate else { return false }
                return airDate >= range.start && airDate <= range.end
            }
            .sorted {
                let air = ($0.effectiveAirDate ?? "9999-12-31").localizedCompare($1.effectiveAirDate ?? "9999-12-31")
                if air != .orderedSame { return air == .orderedAscending }
                return ($0.stt ?? 0) < ($1.stt ?? 0)
            }
            .enumerated()
            .compactMap { index, row in row.task(sequence: index + 1) }
    }

    func fetchEditorOptions() async throws -> [VideoTaskEditorOption] {
        guard let client else { throw VideoTaskRepositoryError.configurationMissing }
        let rows: [VideoTaskProfileDTO] = try await client
            .from("profiles")
            .select("""
                id,
                editor_code,
                short_name,
                display_name,
                full_name,
                ui_color,
                avatar_url,
                role,
                active,
                is_active,
                is_editor_member
            """)
            .eq("is_editor_member", value: true)
            .order("role", ascending: true)
            .order("short_name", ascending: true)
            .execute()
            .value
        return rows.compactMap(\.editorOption)
    }

    func createTask(_ data: VideoTaskFormData, userID: UUID?) async throws {
        guard let client else { throw VideoTaskRepositoryError.configurationMissing }
        let payload = try await VideoTaskPayload.make(data: data, client: client, userID: userID, includeCreatedBy: true)
        _ = try await client
            .from("video_tasks")
            .insert(payload)
            .select("id")
            .single()
            .execute()
    }

    func updateTask(id: UUID, data: VideoTaskFormData, previousTask: VideoTask, userID: UUID?, allowLinkedOverride: Bool) async throws {
        guard let client else { throw VideoTaskRepositoryError.configurationMissing }
        if previousTask.isLinked && !allowLinkedOverride {
            throw VideoTaskRepositoryError.backend("Task liên kết cần dùng luồng thao tác riêng.")
        }

        let payload = try await VideoTaskPayload.make(data: data, client: client, userID: userID, includeCreatedBy: false)
        _ = try await client
            .from("video_tasks")
            .update(payload)
            .eq("id", value: id)
            .execute()

        if allowLinkedOverride, previousTask.isLinked, data.status == .done {
            _ = try await client
                .rpc("admin_sync_linked_video_task_completion", params: VideoTaskAdminSyncRPCParams(
                    taskID: id,
                    contentPlanID: previousTask.contentPlanID,
                    resultLink: try VideoTaskURLValidator.normalizeRequired(data.resultLink)
                ))
                .execute()
        }
    }

    func deleteTask(_ task: VideoTask, userID: UUID?) async throws {
        guard let client else { throw VideoTaskRepositoryError.configurationMissing }
        _ = try await client
            .rpc("delete_video_task_with_notifications", params: VideoTaskIDRPCParams(taskID: task.id))
            .execute()
    }

    func acceptLinkedTask(id: UUID, data: VideoTaskAcceptData) async throws {
        guard let client else { throw VideoTaskRepositoryError.configurationMissing }
        _ = try VideoTaskAcceptPayload(data: data)
        _ = try await client
            .rpc("accept_linked_video_task", params: VideoTaskAcceptRPCParams(taskID: id, data: data))
            .execute()
    }

    func updateLinkedExecution(id: UUID, data: VideoTaskExecutionData) async throws {
        guard let client else { throw VideoTaskRepositoryError.configurationMissing }
        _ = try VideoTaskExecutionPayload(data: data)
        _ = try await client
            .rpc("update_linked_video_task_execution", params: VideoTaskExecutionRPCParams(taskID: id, data: data))
            .execute()
    }

    func completeLinkedTask(id: UUID, resultLink: String) async throws {
        guard let client else { throw VideoTaskRepositoryError.configurationMissing }
        _ = try await client
            .rpc("complete_linked_video_task", params: VideoTaskCompleteRPCParams(
                taskID: id,
                resultLink: try VideoTaskURLValidator.normalizeRequired(resultLink)
            ))
            .execute()
    }

    static let taskSelect = """
        id,
        stt,
        title,
        resize_reqs,
        editor_id,
        order_team,
        category,
        receive_date,
        return_date,
        air_date,
        status,
        priority,
        result_link,
        notes,
        content_plan_id,
        content_plan:content_plan_id (
            title,
            note,
            category,
            air_date,
            editor_id,
            profiles!content_plan_editor_id_fkey (
                id,
                editor_code,
                short_name,
                display_name,
                full_name,
                ui_color,
                avatar_url
            )
        ),
        profiles!video_tasks_editor_id_fkey (
            id,
            editor_code,
            short_name,
            display_name,
            full_name,
            ui_color,
            avatar_url
        )
    """
}

struct VideoTaskPayload: Encodable, Equatable {
    var title: String
    var resizeReqs: String?
    var editorID: UUID?
    var orderTeam: String?
    var category: String?
    var receiveDate: String?
    var returnDate: String?
    var airDate: String?
    var status: String
    var priority: String
    var resultLink: String?
    var notes: String?
    var createdBy: UUID?
    var updatedBy: UUID?

    enum CodingKeys: String, CodingKey {
        case title
        case resizeReqs = "resize_reqs"
        case editorID = "editor_id"
        case orderTeam = "order_team"
        case category
        case receiveDate = "receive_date"
        case returnDate = "return_date"
        case airDate = "air_date"
        case status
        case priority
        case resultLink = "result_link"
        case notes
        case createdBy = "created_by"
        case updatedBy = "updated_by"
    }

    static func make(data: VideoTaskFormData, client: SupabaseClient? = nil, userID: UUID? = nil, includeCreatedBy: Bool = false) async throws -> VideoTaskPayload {
        let title = data.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw VideoTaskValidationError.missingTitle }
        guard data.editorCode.isEmpty || data.editorCode.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            throw VideoTaskValidationError.invalidEditor
        }
        guard data.orderTeam.isEmpty || VideoTaskConstants.orderTeams.contains(data.orderTeam) else {
            throw VideoTaskValidationError.invalidOrderTeam
        }
        let receiveDate = try normalizedDate(data.receiveDate, label: "Ngày nhận")
        let returnDate = try normalizedDate(data.returnDate, label: "Ngày trả")
        let airDate = try normalizedDate(data.airDate, label: "Ngày Air")
        if let receiveDate, let returnDate, returnDate < receiveDate {
            throw VideoTaskValidationError.returnBeforeReceive
        }
        let editorID: UUID?
        if let client {
            editorID = try await resolveEditorProfileID(editorCode: data.editorCode, client: client)
        } else {
            editorID = nil
        }
        return VideoTaskPayload(
            title: title,
            resizeReqs: data.resize.trimmingCharacters(in: .whitespacesAndNewlines).videoNilIfEmpty,
            editorID: editorID,
            orderTeam: data.orderTeam.videoNilIfEmpty,
            category: data.category.rawValue,
            receiveDate: receiveDate,
            returnDate: returnDate,
            airDate: airDate,
            status: data.status.rawValue,
            priority: data.priority.rawValue,
            resultLink: try VideoTaskURLValidator.normalizeOptional(data.resultLink),
            notes: data.note.trimmingCharacters(in: .whitespacesAndNewlines).videoNilIfEmpty,
            createdBy: includeCreatedBy ? userID : nil,
            updatedBy: userID
        )
    }

    private static func normalizedDate(_ value: String, label: String) throws -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        guard VideoTaskDateFormatter.isValidISODate(clean) else {
            throw VideoTaskValidationError.invalidDate(label)
        }
        return clean
    }

    private static func resolveEditorProfileID(editorCode: String, client: SupabaseClient) async throws -> UUID? {
        let clean = editorCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return nil }
        let row: VideoTaskEditorIdentityDTO? = try await client
            .from("profiles")
            .select("id")
            .eq("is_editor_member", value: true)
            .ilike("editor_code", pattern: clean)
            .maybeSingle()
            .execute()
            .value
        return row?.id
    }
}

struct VideoTaskAcceptPayload: Equatable {
    var receiveDate: String
    var returnDate: String

    init(data: VideoTaskAcceptData) throws {
        guard VideoTaskDateFormatter.isValidISODate(data.receiveDate) else {
            throw VideoTaskValidationError.invalidDate("Ngày nhận")
        }
        guard VideoTaskDateFormatter.isValidISODate(data.returnDate) else {
            throw VideoTaskValidationError.invalidDate("Ngày trả")
        }
        guard data.returnDate >= data.receiveDate else {
            throw VideoTaskValidationError.returnBeforeReceive
        }
        receiveDate = data.receiveDate
        returnDate = data.returnDate
    }
}

struct VideoTaskExecutionPayload: Equatable {
    var orderTeam: String?
    var priority: VideoTaskPriority
    var resize: String?
    var receiveDate: String
    var returnDate: String
    var resultLink: String?

    init(data: VideoTaskExecutionData) throws {
        guard data.orderTeam.isEmpty || VideoTaskConstants.orderTeams.contains(data.orderTeam) else {
            throw VideoTaskValidationError.invalidOrderTeam
        }
        guard VideoTaskDateFormatter.isValidISODate(data.receiveDate) else {
            throw VideoTaskValidationError.invalidDate("Ngày nhận")
        }
        guard VideoTaskDateFormatter.isValidISODate(data.returnDate) else {
            throw VideoTaskValidationError.invalidDate("Ngày trả")
        }
        guard data.returnDate >= data.receiveDate else {
            throw VideoTaskValidationError.returnBeforeReceive
        }
        orderTeam = data.orderTeam.videoNilIfEmpty
        priority = data.priority
        resize = data.resize.videoNilIfEmpty
        receiveDate = data.receiveDate
        returnDate = data.returnDate
        resultLink = try VideoTaskURLValidator.normalizeOptional(data.resultLink)
    }
}

enum VideoTaskRPCContract {
    static func acceptParams(id: UUID, data: VideoTaskAcceptData) throws -> [String: String] {
        let payload = try VideoTaskAcceptPayload(data: data)
        return [
            "p_video_task_id": id.uuidString,
            "p_receive_date": payload.receiveDate,
            "p_return_date": payload.returnDate
        ]
    }

    static func executionParams(id: UUID, data: VideoTaskExecutionData) throws -> [String: String] {
        let payload = try VideoTaskExecutionPayload(data: data)
        return [
            "p_video_task_id": id.uuidString,
            "p_order_team": payload.orderTeam ?? "",
            "p_priority": payload.priority.rawValue,
            "p_resize_reqs": payload.resize ?? "",
            "p_receive_date": payload.receiveDate,
            "p_return_date": payload.returnDate,
            "p_result_link": payload.resultLink ?? ""
        ]
    }

    static func completeParams(id: UUID, resultLink: String) throws -> [String: String] {
        [
            "p_video_task_id": id.uuidString,
            "p_result_link": try VideoTaskURLValidator.normalizeRequired(resultLink)
        ]
    }

    static func deleteParams(id: UUID) -> [String: String] {
        ["p_video_task_id": id.uuidString]
    }
}

private struct VideoTaskIDRPCParams: Encodable {
    var pVideoTaskID: UUID
    init(taskID: UUID) { pVideoTaskID = taskID }
    enum CodingKeys: String, CodingKey { case pVideoTaskID = "p_video_task_id" }
}

private struct VideoTaskAcceptRPCParams: Encodable {
    var pVideoTaskID: UUID
    var pReceiveDate: String
    var pReturnDate: String

    init(taskID: UUID, data: VideoTaskAcceptData) {
        pVideoTaskID = taskID
        pReceiveDate = data.receiveDate
        pReturnDate = data.returnDate
    }

    enum CodingKeys: String, CodingKey {
        case pVideoTaskID = "p_video_task_id"
        case pReceiveDate = "p_receive_date"
        case pReturnDate = "p_return_date"
    }
}

private struct VideoTaskExecutionRPCParams: Encodable {
    var pVideoTaskID: UUID
    var pOrderTeam: String?
    var pPriority: String
    var pResizeReqs: String?
    var pReceiveDate: String
    var pReturnDate: String
    var pResultLink: String?

    init(taskID: UUID, data: VideoTaskExecutionData) {
        pVideoTaskID = taskID
        pOrderTeam = data.orderTeam.videoNilIfEmpty
        pPriority = data.priority.rawValue
        pResizeReqs = data.resize.videoNilIfEmpty
        pReceiveDate = data.receiveDate
        pReturnDate = data.returnDate
        pResultLink = try? VideoTaskURLValidator.normalizeOptional(data.resultLink)
    }

    enum CodingKeys: String, CodingKey {
        case pVideoTaskID = "p_video_task_id"
        case pOrderTeam = "p_order_team"
        case pPriority = "p_priority"
        case pResizeReqs = "p_resize_reqs"
        case pReceiveDate = "p_receive_date"
        case pReturnDate = "p_return_date"
        case pResultLink = "p_result_link"
    }
}

private struct VideoTaskCompleteRPCParams: Encodable {
    var pVideoTaskID: UUID
    var pResultLink: String
    init(taskID: UUID, resultLink: String) {
        pVideoTaskID = taskID
        pResultLink = resultLink
    }
    enum CodingKeys: String, CodingKey {
        case pVideoTaskID = "p_video_task_id"
        case pResultLink = "p_result_link"
    }
}

private struct VideoTaskAdminSyncRPCParams: Encodable {
    var pVideoTaskID: UUID
    var pContentPlanID: UUID?
    var pResultLink: String
    init(taskID: UUID, contentPlanID: UUID?, resultLink: String) {
        pVideoTaskID = taskID
        pContentPlanID = contentPlanID
        pResultLink = resultLink
    }
    enum CodingKeys: String, CodingKey {
        case pVideoTaskID = "p_video_task_id"
        case pContentPlanID = "p_content_plan_id"
        case pResultLink = "p_result_link"
    }
}

private struct VideoTaskDTO: Decodable {
    var id: UUID
    var stt: Int?
    var title: String?
    var resizeRequirements: String?
    var editorID: UUID?
    var orderTeam: String?
    var category: String?
    var receiveDate: String?
    var returnDate: String?
    var airDate: String?
    var status: String?
    var priority: String?
    var resultLink: String?
    var notes: String?
    var contentPlanID: UUID?
    var contentPlan: VideoOneOrMany<VideoTaskContentPlanDTO>?
    var profiles: VideoOneOrMany<VideoTaskProfileDTO>?

    enum CodingKeys: String, CodingKey {
        case id
        case stt
        case title
        case resizeRequirements = "resize_reqs"
        case editorID = "editor_id"
        case orderTeam = "order_team"
        case category
        case receiveDate = "receive_date"
        case returnDate = "return_date"
        case airDate = "air_date"
        case status
        case priority
        case resultLink = "result_link"
        case notes
        case contentPlanID = "content_plan_id"
        case contentPlan = "content_plan"
        case profiles
    }

    var effectiveAirDate: String? {
        if contentPlanID != nil, let plan = contentPlan?.first {
            return plan.airDate ?? airDate
        }
        return airDate
    }

    func task(sequence: Int) -> VideoTask? {
        let linkedPlan = contentPlan?.first
        let isLinked = contentPlanID != nil && linkedPlan != nil
        let profile = isLinked ? linkedPlan?.profiles?.first ?? profiles?.first : profiles?.first
        let categoryValue = isLinked && VideoTaskCategory.allCases.map(\.rawValue).contains(linkedPlan?.category ?? "")
            ? linkedPlan?.category
            : category
        return VideoTask(
            id: id,
            contentPlanID: contentPlanID,
            sequence: sequence,
            title: isLinked ? linkedPlan?.title ?? title ?? "" : title ?? "",
            resize: resizeRequirements ?? "",
            editorCode: profile?.editorCode ?? "",
            editorProfileID: profile?.id ?? editorID,
            editorDisplayName: profile?.displayLabel ?? "Chưa phân công",
            orderTeam: orderTeam ?? "",
            category: VideoTaskCategory(rawValue: categoryValue),
            receiveDate: receiveDate,
            returnDate: returnDate,
            airDate: effectiveAirDate,
            status: VideoTaskStatus(rawValue: status ?? "") ?? .waiting,
            priority: VideoTaskPriority(rawValue: priority ?? "") ?? .normal,
            resultLink: resultLink ?? "",
            note: isLinked ? linkedPlan?.note ?? "" : notes ?? ""
        )
    }
}

private struct VideoTaskContentPlanDTO: Decodable {
    var title: String?
    var note: String?
    var category: String?
    var airDate: String?
    var editorID: UUID?
    var profiles: VideoOneOrMany<VideoTaskProfileDTO>?

    enum CodingKeys: String, CodingKey {
        case title
        case note
        case category
        case airDate = "air_date"
        case editorID = "editor_id"
        case profiles
    }
}

private struct VideoTaskProfileDTO: Decodable {
    var id: UUID
    var editorCode: String?
    var shortName: String?
    var displayName: String?
    var fullName: String?
    var uiColor: String?
    var avatarURL: String?
    var active: Bool?
    var isActive: Bool?
    var isEditorMember: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case editorCode = "editor_code"
        case shortName = "short_name"
        case displayName = "display_name"
        case fullName = "full_name"
        case uiColor = "ui_color"
        case avatarURL = "avatar_url"
        case active
        case isActive = "is_active"
        case isEditorMember = "is_editor_member"
    }

    var displayLabel: String {
        shortName.videoNilIfEmpty ?? displayName.videoNilIfEmpty ?? fullName.videoNilIfEmpty ?? editorCode.videoNilIfEmpty ?? "Editor"
    }

    var editorOption: VideoTaskEditorOption? {
        guard isEditorMember == true, isActive != false, active != false, let code = editorCode?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !code.isEmpty else {
            return nil
        }
        let name = fullName.videoNilIfEmpty ?? displayName.videoNilIfEmpty ?? shortName.videoNilIfEmpty ?? code
        let short = shortName.videoNilIfEmpty ?? displayName.videoNilIfEmpty ?? name
        return VideoTaskEditorOption(
            editorCode: code,
            profileID: id,
            name: name,
            shortName: short,
            initials: String(short.prefix(1)).uppercased(),
            colorHex: normalizedVideoColor(uiColor, fallbackSeed: code),
            avatarURL: avatarURL.videoNilIfEmpty.flatMap(URL.init(string:))
        )
    }
}

private struct VideoTaskEditorIdentityDTO: Decodable {
    var id: UUID
}

private struct VideoOneOrMany<Element: Decodable>: Decodable {
    var values: [Element]
    var first: Element? { values.first }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            values = []
        } else if let array = try? container.decode([Element].self) {
            values = array
        } else {
            values = [try container.decode(Element.self)]
        }
    }
}

private func normalizedVideoColor(_ value: String?, fallbackSeed: String) -> String {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          value.range(of: #"^#[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil else {
        let palette = ["#0EA5E9", "#22C55E", "#F59E0B", "#EF4444", "#14B8A6", "#8B5CF6", "#EC4899"]
        let total = fallbackSeed.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[total % palette.count]
    }
    return value.uppercased()
}

extension Optional where Wrapped == String {
    var videoNilIfEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

extension String {
    var videoNilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
