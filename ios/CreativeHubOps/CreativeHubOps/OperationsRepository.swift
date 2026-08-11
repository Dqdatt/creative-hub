import Foundation
import Supabase

protocol OperationsRepositoryServing: Sendable {
    func fetchVideoTasks(range: MonthRange) async throws -> [VideoTask]
    func fetchShoots(range: MonthRange) async throws -> [ShootSchedule]
    func fetchContentPlan(range: MonthRange) async throws -> [ContentPlanItem]
    func fetchEditors() async throws -> [EditorProfile]
    func createVideoTask(_ data: VideoTaskFormData, userId: UUID?) async throws
    func updateVideoTask(_ task: VideoTask, data: VideoTaskFormData, userId: UUID?) async throws
    func deleteVideoTask(_ task: VideoTask) async throws
    func acceptLinkedVideoTask(_ task: VideoTask, data: LinkedTaskAcceptFormData) async throws
    func updateLinkedVideoTaskExecution(_ task: VideoTask, data: LinkedTaskExecutionFormData) async throws
    func completeLinkedVideoTask(_ task: VideoTask, data: LinkedTaskExecutionFormData) async throws
    func createShoot(_ data: ShootFormData) async throws
    func updateShoot(_ shoot: ShootSchedule, data: ShootFormData) async throws
    func deleteShoot(_ shoot: ShootSchedule) async throws
    func createContentPlan(_ data: ContentPlanFormData) async throws
    func updateContentPlan(_ item: ContentPlanItem, data: ContentPlanFormData, userId: UUID?) async throws
    func assignContentPlanEditor(_ item: ContentPlanItem, editorCode: String) async throws
    func deleteContentPlan(_ item: ContentPlanItem) async throws
}

final class OperationsRepository: OperationsRepositoryServing {
    private let client: SupabaseClient

    init(config: AppConfig) {
        client = SupabaseClient(supabaseURL: config.supabaseURL, supabaseKey: config.supabaseAnonKey)
    }

    convenience init() throws {
        try self.init(config: AppConfig.current())
    }

    func fetchVideoTasks(range: MonthRange) async throws -> [VideoTask] {
        let rows: [VideoTaskRow] = try await client
            .from("video_tasks")
            .select("id,stt,title,resize_reqs,editor_id,order_team,category,receive_date,return_date,air_date,status,priority,result_link,notes,content_plan_id")
            .order("air_date", ascending: true, nullsFirst: false)
            .order("stt", ascending: true)
            .execute()
            .value

        return rows
            .filter { row in
                [row.airDate, row.returnDate, row.receiveDate].contains { date in
                    guard let date else { return false }
                    return date >= range.startDate && date <= range.endDate
                }
            }
            .map(\.domain)
    }

    func fetchShoots(range: MonthRange) async throws -> [ShootSchedule] {
        let rows: [ShootRow] = try await client
            .from("shoots")
            .select("""
                id,
                shoot_date,
                shoot_type,
                crew,
                time_slot,
                location,
                content_note,
                shoot_editors (
                    profile_id,
                    profiles!shoot_editors_profile_id_fkey (
                        id,
                        editor_code
                    )
                )
            """)
            .gte("shoot_date", value: range.startDate)
            .lte("shoot_date", value: range.endDate)
            .order("shoot_date", ascending: true)
            .order("created_at", ascending: true)
            .execute()
            .value

        return rows.map(\.domain)
    }

    func fetchContentPlan(range: MonthRange) async throws -> [ContentPlanItem] {
        let rows: [ContentPlanRow] = try await client
            .from("content_plan")
            .select("""
                id,
                air_date,
                title,
                note,
                category,
                editor_id,
                link,
                video_tasks!video_tasks_content_plan_id_fkey (
                    id
                ),
                profiles!content_plan_editor_id_fkey (
                    id,
                    editor_code
                )
            """)
            .gte("air_date", value: range.startDate)
            .lte("air_date", value: range.endDate)
            .order("air_date", ascending: true)
            .order("created_at", ascending: true)
            .execute()
            .value

        return rows.map(\.domain)
    }

    func fetchEditors() async throws -> [EditorProfile] {
        let rows: [EditorRow] = try await client
            .from("profiles")
            .select("id,editor_code,short_name,display_name,full_name,ui_color,avatar_url,role,active,is_active,is_editor_member")
            .order("role", ascending: true)
            .order("short_name", ascending: true)
            .execute()
            .value

        return rows
            .compactMap(\.domain)
            .sorted { lhs, rhs in
                if lhs.role == "editor", rhs.role != "editor" { return true }
                if lhs.role != "editor", rhs.role == "editor" { return false }
                return lhs.shortName.localizedCompare(rhs.shortName) == .orderedAscending
            }
    }

    func createVideoTask(_ data: VideoTaskFormData, userId: UUID?) async throws {
        let payload = try await makeVideoTaskPayload(data, userId: userId, includeCreatedBy: true)

        try await client
            .from("video_tasks")
            .insert(payload)
            .select("id")
            .single()
            .execute()
    }

    func updateVideoTask(_ task: VideoTask, data: VideoTaskFormData, userId: UUID?) async throws {
        let payload = try await makeVideoTaskPayload(data, userId: userId, includeCreatedBy: false)
        try validateTaskUpdate(task: task, data: data, payload: payload)

        try await client
            .from("video_tasks")
            .update(payload)
            .eq("id", value: task.id)
            .execute()
    }

    func deleteVideoTask(_ task: VideoTask) async throws {
        do {
            try await client
                .rpc("delete_video_task_with_notifications", params: DeleteVideoTaskRPCParams(pVideoTaskId: task.id))
                .execute()
        } catch {
            let message = error.localizedDescription.lowercased()
            let isMissingRPC = message.contains("pgrst202") ||
                message.contains("could not find the function") ||
                message.contains("delete_video_task_with_notifications")

            guard isMissingRPC else {
                throw error
            }

            try await client
                .from("video_tasks")
                .delete()
                .eq("id", value: task.id)
                .execute()
        }
    }

    func acceptLinkedVideoTask(_ task: VideoTask, data: LinkedTaskAcceptFormData) async throws {
        let receiveDate = try requiredNormalizedTaskDate(data.receiveDate, label: "Ngày nhận")
        let returnDate = try requiredNormalizedTaskDate(data.returnDate, label: "Ngày trả")
        guard returnDate >= receiveDate else {
            throw AppError.validation("Ngày nhận và Ngày trả chưa hợp lệ.")
        }

        let rows: [AcceptLinkedVideoTaskRPCRow] = try await client
            .rpc(
                "accept_linked_video_task",
                params: AcceptLinkedVideoTaskRPCParams(
                    pVideoTaskId: task.id,
                    pReceiveDate: receiveDate,
                    pReturnDate: returnDate
                )
            )
            .execute()
            .value

        guard rows.first != nil else {
            throw AppError.backend("Không nhận được kết quả nhận Task.")
        }
    }

    func updateLinkedVideoTaskExecution(_ task: VideoTask, data: LinkedTaskExecutionFormData) async throws {
        _ = try await updateLinkedVideoTaskExecutionRPC(task, data: data)
    }

    func completeLinkedVideoTask(_ task: VideoTask, data: LinkedTaskExecutionFormData) async throws {
        try await updateLinkedVideoTaskExecution(task, data: data)
        let resultLink = try AppDateFormatter.normalizedRequiredHTTPURL(data.resultLink)

        let rows: [CompleteLinkedVideoTaskRPCRow] = try await client
            .rpc(
                "complete_linked_video_task",
                params: CompleteLinkedVideoTaskRPCParams(
                    pVideoTaskId: task.id,
                    pResultLink: resultLink
                )
            )
            .execute()
            .value

        guard rows.first != nil else {
            throw AppError.backend("Không nhận được kết quả hoàn thành Task.")
        }
    }

    func createShoot(_ data: ShootFormData) async throws {
        let params = try makeShootRPCParams(data)

        try await client
            .rpc("create_shoot_with_notifications", params: params.createParams)
            .execute()
    }

    func updateShoot(_ shoot: ShootSchedule, data: ShootFormData) async throws {
        let params = try makeShootRPCParams(data)

        try await client
            .rpc("update_shoot_with_notifications", params: params.updateParams(shootId: shoot.id))
            .execute()
    }

    func deleteShoot(_ shoot: ShootSchedule) async throws {
        try await client
            .rpc("delete_shoot_with_notifications", params: DeleteShootRPCParams(pShootId: shoot.id))
            .execute()
    }

    func createContentPlan(_ data: ContentPlanFormData) async throws {
        let payload = try makeContentPlanPayload(data, userId: nil)

        try await client
            .rpc(
                "create_content_plan_with_notifications",
                params: CreateContentPlanRPCParams(
                    pAirDate: payload.airDate,
                    pTitle: payload.title,
                    pNote: payload.note,
                    pCategory: payload.category,
                    pLink: payload.link
                )
            )
            .execute()
    }

    func updateContentPlan(_ item: ContentPlanItem, data: ContentPlanFormData, userId: UUID?) async throws {
        var payload = try makeContentPlanPayload(data, userId: userId)
        if item.hasLinkedTask {
            payload.link = item.link.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        }

        try await client
            .from("content_plan")
            .update(payload)
            .eq("id", value: item.id)
            .execute()
    }

    func assignContentPlanEditor(_ item: ContentPlanItem, editorCode: String) async throws {
        let editorProfileId = try await resolveEditorProfileId(editorCode: editorCode)

        try await client
            .rpc(
                "assign_content_plan_editor",
                params: AssignContentPlanEditorRPCParams(
                    pContentPlanId: item.id,
                    pEditorId: editorProfileId
                )
            )
            .execute()
    }

    func deleteContentPlan(_ item: ContentPlanItem) async throws {
        try await client
            .rpc("delete_content_plan_with_notifications", params: DeleteContentPlanRPCParams(pContentPlanId: item.id))
            .execute()
    }

    private func makeVideoTaskPayload(_ data: VideoTaskFormData, userId: UUID?, includeCreatedBy: Bool) async throws -> VideoTaskPayload {
        let cleanTitle = data.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            throw AppError.validation("Vui lòng nhập tên video.")
        }

        let receiveDate = try AppDateFormatter.normalizedDatabaseDate(data.receiveDate, label: "Ngày nhận")
        let returnDate = try AppDateFormatter.normalizedDatabaseDate(data.returnDate, label: "Ngày trả")
        let airDate = try AppDateFormatter.normalizedDatabaseDate(data.airDate, label: "Ngày Air")

        if let receiveDate, let returnDate, returnDate < receiveDate {
            throw AppError.validation("Ngày trả phải sau hoặc bằng Ngày nhận.")
        }

        let resultLink = try AppDateFormatter.normalizedOptionalHTTPURL(data.resultLink)
        let editorProfileId = try await resolveEditorProfileId(editorCode: data.editorCode)

        return VideoTaskPayload(
            title: cleanTitle,
            resizeReqs: data.resizeRequirements.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
            editorId: editorProfileId,
            orderTeam: data.orderTeam.nilIfBlank,
            category: data.category.nilIfBlank,
            receiveDate: receiveDate,
            returnDate: returnDate,
            airDate: airDate,
            status: data.status.rawValue,
            priority: data.priority,
            resultLink: resultLink,
            notes: data.notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
            createdBy: includeCreatedBy ? userId?.uuidString : nil,
            updatedBy: userId?.uuidString
        )
    }

    private func validateTaskUpdate(task: VideoTask, data: VideoTaskFormData, payload: VideoTaskPayload) throws {
        guard task.contentPlanId != nil else { return }

        if (task.editorId ?? "") != (payload.editorId ?? "") {
            throw AppError.validation("Hãy đổi Editor của Task liên kết từ Content Plan.")
        }

        if (task.airDate ?? "") != (payload.airDate ?? "") {
            throw AppError.validation("Ngày Air của Task liên kết được quản lý từ Content Plan.")
        }

        let nextLink = payload.resultLink ?? ""
        if task.status == .doing && (data.status == .done || task.resultLink != nextLink) {
            throw AppError.validation("Hãy hoàn thành Task liên kết qua thao tác Hoàn thành.")
        }

        if task.status == .done && (task.status != data.status || task.resultLink != nextLink) {
            throw AppError.validation("Hãy hoàn thành Task liên kết qua thao tác Hoàn thành.")
        }
    }

    private func resolveEditorProfileId(editorCode: String) async throws -> String? {
        let cleanCode = editorCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanCode.isEmpty else { return nil }
        if VideoTaskFormData.looksLikeUUID(cleanCode) {
            return cleanCode
        }

        let row: EditorIdRow? = try await client
            .from("profiles")
            .select("id")
            .eq("is_editor_member", value: true)
            .ilike("editor_code", pattern: cleanCode)
            .maybeSingle()
            .execute()
            .value

        return row?.id
    }

    private func makeShootRPCParams(_ data: ShootFormData) throws -> ShootRPCParams {
        let date = try normalizedISODate(data.date, label: "Ngày quay")
        let place = data.place.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !place.isEmpty else {
            throw AppError.validation("Vui lòng nhập địa điểm lịch quay.")
        }

        return ShootRPCParams(
            shootDate: date,
            shootType: data.type.rawValue,
            crew: data.crew.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
            timeSlot: data.time.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
            location: place,
            contentNote: data.note.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
            editorCodes: Array(data.editorIds).sorted()
        )
    }

    private func makeContentPlanPayload(_ data: ContentPlanFormData, userId: UUID?) throws -> ContentPlanPayload {
        let title = data.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            throw AppError.validation("Vui lòng nhập tên video.")
        }

        let note = data.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard note.count <= 2_000 else {
            throw AppError.validation("Ghi chú tối đa 2000 ký tự.")
        }

        return ContentPlanPayload(
            airDate: try normalizedISODate(data.airDate, label: "Ngày Air"),
            title: title,
            note: note.nilIfBlank,
            category: data.category.rawValue,
            link: try AppDateFormatter.normalizedOptionalHTTPURL(data.link),
            updatedBy: userId?.uuidString
        )
    }

    private func normalizedISODate(_ value: String, label: String) throws -> String {
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanValue.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else {
            throw AppError.validation("\(label) chưa đúng định dạng YYYY-MM-DD.")
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: cleanValue), formatter.string(from: date) == cleanValue else {
            throw AppError.validation("\(label) không hợp lệ.")
        }

        return cleanValue
    }

    private func requiredNormalizedTaskDate(_ value: String, label: String) throws -> String {
        guard let date = try AppDateFormatter.normalizedDatabaseDate(value, label: label) else {
            throw AppError.validation("\(label) chưa hợp lệ.")
        }
        return date
    }

    private func updateLinkedVideoTaskExecutionRPC(_ task: VideoTask, data: LinkedTaskExecutionFormData) async throws -> UpdateLinkedVideoTaskExecutionRPCRow {
        let receiveDate = try requiredNormalizedTaskDate(data.receiveDate, label: "Ngày nhận")
        let returnDate = try requiredNormalizedTaskDate(data.returnDate, label: "Ngày trả")
        guard returnDate >= receiveDate else {
            throw AppError.validation("Ngày nhận và Ngày trả chưa hợp lệ.")
        }
        let resultLink = try AppDateFormatter.normalizedOptionalHTTPURL(data.resultLink)

        let rows: [UpdateLinkedVideoTaskExecutionRPCRow] = try await client
            .rpc(
                "update_linked_video_task_execution",
                params: UpdateLinkedVideoTaskExecutionRPCParams(
                    pVideoTaskId: task.id,
                    pOrderTeam: data.orderTeam.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                    pPriority: data.priority,
                    pResizeReqs: data.resizeRequirements.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                    pReceiveDate: receiveDate,
                    pReturnDate: returnDate,
                    pResultLink: resultLink
                )
            )
            .execute()
            .value

        guard let row = rows.first else {
            throw AppError.backend("Không nhận được kết quả lưu thông tin thực hiện Task.")
        }
        return row
    }
}

private struct AcceptLinkedVideoTaskRPCParams: Encodable {
    let pVideoTaskId: String
    let pReceiveDate: String
    let pReturnDate: String

    enum CodingKeys: String, CodingKey {
        case pVideoTaskId = "p_video_task_id"
        case pReceiveDate = "p_receive_date"
        case pReturnDate = "p_return_date"
    }
}

private struct UpdateLinkedVideoTaskExecutionRPCParams: Encodable {
    let pVideoTaskId: String
    let pOrderTeam: String?
    let pPriority: String
    let pResizeReqs: String?
    let pReceiveDate: String
    let pReturnDate: String
    let pResultLink: String?

    enum CodingKeys: String, CodingKey {
        case pVideoTaskId = "p_video_task_id"
        case pOrderTeam = "p_order_team"
        case pPriority = "p_priority"
        case pResizeReqs = "p_resize_reqs"
        case pReceiveDate = "p_receive_date"
        case pReturnDate = "p_return_date"
        case pResultLink = "p_result_link"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pVideoTaskId, forKey: .pVideoTaskId)
        try encodeNullable(pOrderTeam, into: &container, key: .pOrderTeam)
        try container.encode(pPriority, forKey: .pPriority)
        try encodeNullable(pResizeReqs, into: &container, key: .pResizeReqs)
        try container.encode(pReceiveDate, forKey: .pReceiveDate)
        try container.encode(pReturnDate, forKey: .pReturnDate)
        try encodeNullable(pResultLink, into: &container, key: .pResultLink)
    }
}

private struct CompleteLinkedVideoTaskRPCParams: Encodable {
    let pVideoTaskId: String
    let pResultLink: String

    enum CodingKeys: String, CodingKey {
        case pVideoTaskId = "p_video_task_id"
        case pResultLink = "p_result_link"
    }
}

private struct AcceptLinkedVideoTaskRPCRow: Decodable {
    let videoTaskId: String
    let contentPlanId: String
    let status: String
    let receiveDate: String
    let returnDate: String
    let airDate: String
    let editorId: String

    enum CodingKeys: String, CodingKey {
        case videoTaskId = "video_task_id"
        case contentPlanId = "content_plan_id"
        case status
        case receiveDate = "receive_date"
        case returnDate = "return_date"
        case airDate = "air_date"
        case editorId = "editor_id"
    }
}

private struct UpdateLinkedVideoTaskExecutionRPCRow: Decodable {
    let videoTaskId: String
    let contentPlanId: String
    let status: String
    let orderTeam: String?
    let priority: String?
    let resizeReqs: String?
    let receiveDate: String
    let returnDate: String
    let resultLink: String?
    let editorId: String
    let changedFields: [String]?

    enum CodingKeys: String, CodingKey {
        case videoTaskId = "video_task_id"
        case contentPlanId = "content_plan_id"
        case status
        case orderTeam = "order_team"
        case priority
        case resizeReqs = "resize_reqs"
        case receiveDate = "receive_date"
        case returnDate = "return_date"
        case resultLink = "result_link"
        case editorId = "editor_id"
        case changedFields = "changed_fields"
    }
}

private struct CompleteLinkedVideoTaskRPCRow: Decodable {
    let videoTaskId: String
    let contentPlanId: String
    let status: String
    let resultLink: String
    let contentPlanLink: String
    let completedAt: String
    let editorId: String
    let airDate: String

    enum CodingKeys: String, CodingKey {
        case videoTaskId = "video_task_id"
        case contentPlanId = "content_plan_id"
        case status
        case resultLink = "result_link"
        case contentPlanLink = "content_plan_link"
        case completedAt = "completed_at"
        case editorId = "editor_id"
        case airDate = "air_date"
    }
}

private struct VideoTaskPayload: Encodable {
    let title: String
    let resizeReqs: String?
    let editorId: String?
    let orderTeam: String?
    let category: String?
    let receiveDate: String?
    let returnDate: String?
    let airDate: String?
    let status: String
    let priority: String
    let resultLink: String?
    let notes: String?
    let createdBy: String?
    let updatedBy: String?

    enum CodingKeys: String, CodingKey {
        case title
        case resizeReqs = "resize_reqs"
        case editorId = "editor_id"
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
}

private struct DeleteVideoTaskRPCParams: Encodable {
    let pVideoTaskId: String

    enum CodingKeys: String, CodingKey {
        case pVideoTaskId = "p_video_task_id"
    }
}

private struct ShootRPCParams {
    let shootDate: String
    let shootType: String
    let crew: String?
    let timeSlot: String?
    let location: String
    let contentNote: String?
    let editorCodes: [String]

    var createParams: CreateShootRPCParams {
        CreateShootRPCParams(
            pShootDate: shootDate,
            pShootType: shootType,
            pCrew: crew,
            pTimeSlot: timeSlot,
            pLocation: location,
            pContentNote: contentNote,
            pEditorCodes: editorCodes
        )
    }

    func updateParams(shootId: String) -> UpdateShootRPCParams {
        UpdateShootRPCParams(
            pShootId: shootId,
            pShootDate: shootDate,
            pShootType: shootType,
            pCrew: crew,
            pTimeSlot: timeSlot,
            pLocation: location,
            pContentNote: contentNote,
            pEditorCodes: editorCodes
        )
    }
}

private struct CreateShootRPCParams: Encodable {
    let pShootDate: String
    let pShootType: String
    let pCrew: String?
    let pTimeSlot: String?
    let pLocation: String
    let pContentNote: String?
    let pEditorCodes: [String]

    enum CodingKeys: String, CodingKey {
        case pShootDate = "p_shoot_date"
        case pShootType = "p_shoot_type"
        case pCrew = "p_crew"
        case pTimeSlot = "p_time_slot"
        case pLocation = "p_location"
        case pContentNote = "p_content_note"
        case pEditorCodes = "p_editor_codes"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pShootDate, forKey: .pShootDate)
        try container.encode(pShootType, forKey: .pShootType)
        try encodeNullable(pCrew, into: &container, key: .pCrew)
        try encodeNullable(pTimeSlot, into: &container, key: .pTimeSlot)
        try container.encode(pLocation, forKey: .pLocation)
        try encodeNullable(pContentNote, into: &container, key: .pContentNote)
        try container.encode(pEditorCodes, forKey: .pEditorCodes)
    }
}

private struct UpdateShootRPCParams: Encodable {
    let pShootId: String
    let pShootDate: String
    let pShootType: String
    let pCrew: String?
    let pTimeSlot: String?
    let pLocation: String
    let pContentNote: String?
    let pEditorCodes: [String]

    enum CodingKeys: String, CodingKey {
        case pShootId = "p_shoot_id"
        case pShootDate = "p_shoot_date"
        case pShootType = "p_shoot_type"
        case pCrew = "p_crew"
        case pTimeSlot = "p_time_slot"
        case pLocation = "p_location"
        case pContentNote = "p_content_note"
        case pEditorCodes = "p_editor_codes"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pShootId, forKey: .pShootId)
        try container.encode(pShootDate, forKey: .pShootDate)
        try container.encode(pShootType, forKey: .pShootType)
        try encodeNullable(pCrew, into: &container, key: .pCrew)
        try encodeNullable(pTimeSlot, into: &container, key: .pTimeSlot)
        try container.encode(pLocation, forKey: .pLocation)
        try encodeNullable(pContentNote, into: &container, key: .pContentNote)
        try container.encode(pEditorCodes, forKey: .pEditorCodes)
    }
}

private struct DeleteShootRPCParams: Encodable {
    let pShootId: String

    enum CodingKeys: String, CodingKey {
        case pShootId = "p_shoot_id"
    }
}

private struct ContentPlanPayload: Encodable {
    let airDate: String
    let title: String
    let note: String?
    let category: String?
    var link: String?
    let updatedBy: String?

    enum CodingKeys: String, CodingKey {
        case airDate = "air_date"
        case title
        case note
        case category
        case link
        case updatedBy = "updated_by"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(airDate, forKey: .airDate)
        try container.encode(title, forKey: .title)
        try encodeNullable(note, into: &container, key: .note)
        try encodeNullable(category, into: &container, key: .category)
        try encodeNullable(link, into: &container, key: .link)
        try encodeNullable(updatedBy, into: &container, key: .updatedBy)
    }
}

private struct CreateContentPlanRPCParams: Encodable {
    let pAirDate: String
    let pTitle: String
    let pNote: String?
    let pCategory: String?
    let pLink: String?

    enum CodingKeys: String, CodingKey {
        case pAirDate = "p_air_date"
        case pTitle = "p_title"
        case pNote = "p_note"
        case pCategory = "p_category"
        case pLink = "p_link"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pAirDate, forKey: .pAirDate)
        try container.encode(pTitle, forKey: .pTitle)
        try encodeNullable(pNote, into: &container, key: .pNote)
        try encodeNullable(pCategory, into: &container, key: .pCategory)
        try encodeNullable(pLink, into: &container, key: .pLink)
    }
}

private struct AssignContentPlanEditorRPCParams: Encodable {
    let pContentPlanId: String
    let pEditorId: String?

    enum CodingKeys: String, CodingKey {
        case pContentPlanId = "p_content_plan_id"
        case pEditorId = "p_editor_id"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pContentPlanId, forKey: .pContentPlanId)
        try encodeNullable(pEditorId, into: &container, key: .pEditorId)
    }
}

private struct DeleteContentPlanRPCParams: Encodable {
    let pContentPlanId: String

    enum CodingKeys: String, CodingKey {
        case pContentPlanId = "p_content_plan_id"
    }
}

private func encodeNullable<Key: CodingKey>(
    _ value: String?,
    into container: inout KeyedEncodingContainer<Key>,
    key: Key
) throws {
    if let value {
        try container.encode(value, forKey: key)
    } else {
        try container.encodeNil(forKey: key)
    }
}

private struct EditorIdRow: Decodable {
    let id: String
}

private struct VideoTaskRow: Decodable {
    let id: String
    let stt: Int?
    let title: String?
    let resizeReqs: String?
    let editorId: String?
    let orderTeam: String?
    let category: String?
    let receiveDate: String?
    let returnDate: String?
    let airDate: String?
    let status: String?
    let priority: String?
    let resultLink: String?
    let notes: String?
    let contentPlanId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case stt
        case title
        case resizeReqs = "resize_reqs"
        case editorId = "editor_id"
        case orderTeam = "order_team"
        case category
        case receiveDate = "receive_date"
        case returnDate = "return_date"
        case airDate = "air_date"
        case status
        case priority
        case resultLink = "result_link"
        case notes
        case contentPlanId = "content_plan_id"
    }

    var domain: VideoTask {
        VideoTask(
            id: id,
            sequence: stt,
            title: title?.nilIfBlank ?? "Chưa đặt tên",
            resizeRequirements: resizeReqs ?? "",
            editorId: editorId,
            orderTeam: orderTeam ?? "",
            category: category ?? ContentPlanCategory.longVideo.rawValue,
            receiveDate: receiveDate,
            returnDate: returnDate,
            airDate: airDate,
            status: TaskStatus(rawValue: status ?? "") ?? .waiting,
            priority: priority ?? "",
            resultLink: resultLink ?? "",
            notes: notes ?? "",
            contentPlanId: contentPlanId
        )
    }
}

private struct ContentPlanRow: Decodable {
    let id: String
    let airDate: String
    let title: String?
    let note: String?
    let category: String?
    let editorId: String?
    let link: String?
    let videoTasks: [LinkedVideoTaskRow]?
    let profiles: EditorCodeRow?

    enum CodingKeys: String, CodingKey {
        case id
        case airDate = "air_date"
        case title
        case note
        case category
        case editorId = "editor_id"
        case link
        case videoTasks = "video_tasks"
        case profiles
    }

    var domain: ContentPlanItem {
        ContentPlanItem(
            id: id,
            airDate: airDate,
            title: title?.nilIfBlank ?? "Chưa đặt tên",
            note: note ?? "",
            category: ContentPlanCategory(rawValue: category ?? "") ?? .longVideo,
            editorId: profiles?.editorCode?.nilIfBlank ?? editorId,
            link: link ?? "",
            hasLinkedTask: videoTasks?.isEmpty == false
        )
    }
}

private struct LinkedVideoTaskRow: Decodable {
    let id: String
}

private struct ShootRow: Decodable {
    let id: String
    let shootDate: String
    let shootType: String?
    let crew: String?
    let timeSlot: String?
    let location: String?
    let contentNote: String?
    let shootEditors: [ShootEditorRow]?

    enum CodingKeys: String, CodingKey {
        case id
        case shootDate = "shoot_date"
        case shootType = "shoot_type"
        case crew
        case timeSlot = "time_slot"
        case location
        case contentNote = "content_note"
        case shootEditors = "shoot_editors"
    }

    var domain: ShootSchedule {
        let editors = (shootEditors ?? []).compactMap(\.domain)
        return ShootSchedule(
            id: id,
            date: shootDate,
            type: shootType ?? "other",
            crew: crew ?? "",
            timeSlot: timeSlot ?? "",
            location: location ?? "",
            note: contentNote ?? "",
            editorIds: editors.map(\.editorId),
            editorProfileIds: editors.map(\.profileId)
        )
    }
}

private struct ShootEditorRow: Decodable {
    let profileId: String?
    let profiles: EditorCodeRow?

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case profiles
    }

    var domain: (editorId: String, profileId: String)? {
        guard let profileId else { return nil }
        return (profiles?.editorCode?.nilIfBlank ?? profileId, profileId)
    }
}

private struct EditorCodeRow: Decodable {
    let id: String?
    let editorCode: String?

    enum CodingKeys: String, CodingKey {
        case id
        case editorCode = "editor_code"
    }
}

private struct EditorRow: Decodable {
    let id: String
    let editorCode: String?
    let shortName: String?
    let displayName: String?
    let fullName: String?
    let uiColor: String?
    let avatarURL: String?
    let role: String?
    let active: Bool?
    let isActive: Bool?
    let isEditorMember: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case editorCode = "editor_code"
        case shortName = "short_name"
        case displayName = "display_name"
        case fullName = "full_name"
        case uiColor = "ui_color"
        case avatarURL = "avatar_url"
        case role
        case active
        case isActive = "is_active"
        case isEditorMember = "is_editor_member"
    }

    var domain: EditorProfile? {
        guard let editorCode = editorCode?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !editorCode.isEmpty else {
            return nil
        }
        guard (isActive ?? active ?? true) == true, isEditorMember == true else {
            return nil
        }

        let name = fullName?.nilIfBlank ?? displayName?.nilIfBlank ?? shortName?.nilIfBlank ?? editorCode
        let short = shortName?.nilIfBlank ?? displayName?.nilIfBlank ?? name

        return EditorProfile(
            id: editorCode,
            profileId: id,
            name: name,
            shortName: short,
            initial: short.first.map { String($0).uppercased() } ?? "?",
            colorHex: Self.validColor(uiColor) ?? Self.fallbackColor(seed: editorCode),
            avatarURL: avatarURL ?? "",
            role: role ?? "editor"
        )
    }

    private static func validColor(_ value: String?) -> String? {
        guard let value, value.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil else {
            return nil
        }
        return value
    }

    private static func fallbackColor(seed: String) -> String {
        let palette = ["#0ea5e9", "#22c55e", "#f59e0b", "#ef4444", "#14b8a6", "#8b5cf6", "#ec4899"]
        let index = seed.unicodeScalars.reduce(0) { $0 + Int($1.value) } % palette.count
        return palette[index]
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
