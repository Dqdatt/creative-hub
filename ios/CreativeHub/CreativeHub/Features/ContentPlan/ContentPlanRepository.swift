import Foundation
import Supabase

protocol ContentPlanDataProviding: Sendable {
    var usesProductionData: Bool { get }
    func fetchItems(monthValue: String) async throws -> [ContentPlanItem]
    func fetchEditorOptions() async throws -> [ContentPlanEditorOption]
    func createItem(_ data: ContentPlanFormData, userID: UUID?) async throws
    func updateItem(id: UUID, data: ContentPlanFormData, previousItem: ContentPlanItem, userID: UUID?) async throws
    func assignEditor(id: UUID, editorCode: String) async throws -> ContentPlanAssignEditorResult
    func deleteItem(id: UUID) async throws
}

struct ContentPlanAssignEditorResult: Equatable, Sendable {
    var contentPlanID: UUID
    var videoTaskID: UUID?
    var editorID: UUID?
    var taskCreated: Bool
    var taskStatus: String?
    var airDate: String
}

struct ContentPlanSupabaseRepository: ContentPlanDataProviding {
    var usesProductionData: Bool { true }

    private let client: SupabaseClient?

    init(client: SupabaseClient? = SupabaseService.shared.client) {
        self.client = client
    }

    func fetchItems(monthValue: String) async throws -> [ContentPlanItem] {
        guard let client else { throw ContentPlanRepositoryError.configurationMissing }
        let range = ContentPlanDateFormatter.monthRange(monthValue)
        let rows: [ContentPlanDTO] = try await client
            .from("content_plan")
            .select(Self.contentPlanSelect)
            .gte("air_date", value: range.start)
            .lte("air_date", value: range.end)
            .order("air_date", ascending: true)
            .order("created_at", ascending: true)
            .execute()
            .value
        return rows
            .compactMap(\.item)
            .sorted(by: ContentPlanSorter.areInIncreasingOrder)
            .enumerated()
            .map { _, item in item }
    }

    func fetchEditorOptions() async throws -> [ContentPlanEditorOption] {
        guard let client else { throw ContentPlanRepositoryError.configurationMissing }
        let rows: [ContentPlanProfileDTO] = try await client
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
            .order("role", ascending: true)
            .order("short_name", ascending: true)
            .execute()
            .value
        return rows.compactMap(\.editorOption).sorted { lhs, rhs in
            if lhs.role == "editor", rhs.role != "editor" { return true }
            if lhs.role != "editor", rhs.role == "editor" { return false }
            return lhs.shortName.localizedCompare(rhs.shortName) == .orderedAscending
        }
    }

    func createItem(_ data: ContentPlanFormData, userID: UUID?) async throws {
        guard let client else { throw ContentPlanRepositoryError.configurationMissing }
        let payload = try ContentPlanPayload(data: data, includeEditor: false)
        let result: [ContentPlanCreateResultDTO] = try await client
            .rpc("create_content_plan_with_notifications", params: ContentPlanCreateRPCParams(payload: payload))
            .execute()
            .value
        guard result.first?.contentPlanID != nil else {
            throw ContentPlanRepositoryError.backend("Không nhận được kết quả tạo Content Plan.")
        }
    }

    func updateItem(id: UUID, data: ContentPlanFormData, previousItem: ContentPlanItem, userID: UUID?) async throws {
        guard let client else { throw ContentPlanRepositoryError.configurationMissing }
        var payload = try ContentPlanPayload(data: data, includeEditor: false)
        if previousItem.hasLinkedTask {
            payload.link = previousItem.link.videoNilIfEmpty
        }
        _ = try await client
            .from("content_plan")
            .update(payload)
            .eq("id", value: id)
            .execute()
    }

    func assignEditor(id: UUID, editorCode: String) async throws -> ContentPlanAssignEditorResult {
        guard let client else { throw ContentPlanRepositoryError.configurationMissing }
        let editorProfileID = try await resolveEditorProfileID(editorCode: editorCode, client: client)
        let rows: [ContentPlanAssignEditorDTO] = try await client
            .rpc("assign_content_plan_editor", params: ContentPlanAssignEditorRPCParams(contentPlanID: id, editorID: editorProfileID))
            .execute()
            .value
        guard let result = rows.first?.result else {
            throw ContentPlanRepositoryError.backend("Không nhận được kết quả phân công Content Plan.")
        }
        return result
    }

    func deleteItem(id: UUID) async throws {
        guard let client else { throw ContentPlanRepositoryError.configurationMissing }
        _ = try await client
            .rpc("delete_content_plan_with_notifications", params: ContentPlanDeleteRPCParams(contentPlanID: id))
            .execute()
    }

    private func resolveEditorProfileID(editorCode: String, client: SupabaseClient) async throws -> UUID? {
        let clean = editorCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return nil }
        let row: ContentPlanEditorIdentityDTO? = try await client
            .from("profiles")
            .select("id")
            .eq("is_editor_member", value: true)
            .neq("is_active", value: false)
            .ilike("editor_code", pattern: clean)
            .maybeSingle()
            .execute()
            .value
        return row?.id
    }

    static let contentPlanSelect = """
        id,
        air_date,
        title,
        note,
        category,
        editor_id,
        link,
        created_at,
        video_tasks!video_tasks_content_plan_id_fkey (
            id,
            status
        ),
        profiles!content_plan_editor_id_fkey (
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

struct ContentPlanPayload: Encodable, Equatable {
    var airDate: String
    var title: String
    var note: String?
    var category: String?
    var link: String?
    var editorID: UUID?

    enum CodingKeys: String, CodingKey {
        case airDate = "air_date"
        case title
        case note
        case category
        case link
        case editorID = "editor_id"
    }

    init(data: ContentPlanFormData, includeEditor: Bool) throws {
        let cleanTitle = data.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw ContentPlanValidationError.missingTitle }
        guard ContentPlanDateFormatter.isValidISODate(data.airDate) else { throw ContentPlanValidationError.invalidDate }
        let cleanNote = data.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanNote.count <= 2000 else { throw ContentPlanValidationError.noteTooLong }
        airDate = data.airDate
        title = cleanTitle
        note = cleanNote.videoNilIfEmpty
        category = data.category.rawValue
        link = try VideoTaskURLValidator.normalizeOptional(data.link)
        editorID = includeEditor ? nil : nil
    }
}

enum ContentPlanSorter {
    static func areInIncreasingOrder(_ lhs: ContentPlanItem, _ rhs: ContentPlanItem) -> Bool {
        if lhs.hasSafeLink != rhs.hasSafeLink {
            return rhs.hasSafeLink
        }
        if lhs.airDate != rhs.airDate {
            return lhs.airDate < rhs.airDate
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

enum ContentPlanRPCContract {
    static func createParams(data: ContentPlanFormData) throws -> [String: String] {
        let payload = try ContentPlanPayload(data: data, includeEditor: false)
        return [
            "p_air_date": payload.airDate,
            "p_title": payload.title,
            "p_note": payload.note ?? "",
            "p_category": payload.category ?? "",
            "p_link": payload.link ?? ""
        ]
    }

    static func assignParams(id: UUID, editorProfileID: UUID?) -> [String: String] {
        [
            "p_content_plan_id": id.uuidString,
            "p_editor_id": editorProfileID?.uuidString ?? ""
        ]
    }

    static func deleteParams(id: UUID) -> [String: String] {
        ["p_content_plan_id": id.uuidString]
    }
}

private struct ContentPlanCreateRPCParams: Encodable {
    var pAirDate: String
    var pTitle: String
    var pNote: String?
    var pCategory: String?
    var pLink: String?

    init(payload: ContentPlanPayload) {
        pAirDate = payload.airDate
        pTitle = payload.title
        pNote = payload.note
        pCategory = payload.category
        pLink = payload.link
    }

    enum CodingKeys: String, CodingKey {
        case pAirDate = "p_air_date"
        case pTitle = "p_title"
        case pNote = "p_note"
        case pCategory = "p_category"
        case pLink = "p_link"
    }
}

private struct ContentPlanAssignEditorRPCParams: Encodable {
    var pContentPlanID: UUID
    var pEditorID: UUID?

    init(contentPlanID: UUID, editorID: UUID?) {
        pContentPlanID = contentPlanID
        pEditorID = editorID
    }

    enum CodingKeys: String, CodingKey {
        case pContentPlanID = "p_content_plan_id"
        case pEditorID = "p_editor_id"
    }
}

private struct ContentPlanDeleteRPCParams: Encodable {
    var pContentPlanID: UUID
    init(contentPlanID: UUID) { pContentPlanID = contentPlanID }
    enum CodingKeys: String, CodingKey { case pContentPlanID = "p_content_plan_id" }
}

private struct ContentPlanDTO: Decodable {
    var id: UUID
    var airDate: String
    var title: String?
    var note: String?
    var category: String?
    var editorID: UUID?
    var link: String?
    var createdAt: String?
    var videoTasks: [ContentPlanLinkedTaskDTO]?
    var profiles: ContentPlanOneOrMany<ContentPlanProfileDTO>?

    enum CodingKeys: String, CodingKey {
        case id
        case airDate = "air_date"
        case title
        case note
        case category
        case editorID = "editor_id"
        case link
        case createdAt = "created_at"
        case videoTasks = "video_tasks"
        case profiles
    }

    var item: ContentPlanItem? {
        let profile = profiles?.first
        return ContentPlanItem(
            id: id,
            airDate: airDate,
            title: title ?? "",
            note: note ?? "",
            category: ContentPlanCategory(rawValue: category),
            editorCode: profile?.editorCode ?? "",
            editorProfileID: profile?.id ?? editorID,
            editorDisplayName: profile?.displayLabel ?? "Chưa phân công",
            link: link ?? "",
            linkedVideoTaskID: videoTasks?.first?.id,
            linkedTaskStatus: videoTasks?.first?.status
        )
    }
}

private struct ContentPlanLinkedTaskDTO: Decodable {
    var id: UUID
    var status: String?
}

private struct ContentPlanProfileDTO: Decodable {
    var id: UUID
    var editorCode: String?
    var shortName: String?
    var displayName: String?
    var fullName: String?
    var uiColor: String?
    var avatarURL: String?
    var role: String?
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
        case role
        case active
        case isActive = "is_active"
        case isEditorMember = "is_editor_member"
    }

    var displayLabel: String {
        shortName.videoNilIfEmpty ?? displayName.videoNilIfEmpty ?? fullName.videoNilIfEmpty ?? editorCode.videoNilIfEmpty ?? "Editor"
    }

    var editorOption: ContentPlanEditorOption? {
        guard isEditorMember == true, isActive != false, active != false, let code = editorCode?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !code.isEmpty else {
            return nil
        }
        let name = fullName.videoNilIfEmpty ?? displayName.videoNilIfEmpty ?? shortName.videoNilIfEmpty ?? code
        let short = shortName.videoNilIfEmpty ?? displayName.videoNilIfEmpty ?? name
        return ContentPlanEditorOption(
            editorCode: code,
            profileID: id,
            name: name,
            shortName: short,
            initials: String(short.prefix(1)).uppercased(),
            colorHex: normalizedContentPlanColor(uiColor, fallbackSeed: code),
            avatarURL: avatarURL.videoNilIfEmpty.flatMap(URL.init(string:)),
            role: role ?? "editor"
        )
    }
}

private struct ContentPlanCreateResultDTO: Decodable {
    var contentPlanID: UUID
    enum CodingKeys: String, CodingKey { case contentPlanID = "content_plan_id" }
}

private struct ContentPlanAssignEditorDTO: Decodable {
    var contentPlanID: UUID
    var videoTaskID: UUID?
    var editorID: UUID?
    var taskCreated: Bool
    var taskStatus: String?
    var airDate: String

    enum CodingKeys: String, CodingKey {
        case contentPlanID = "content_plan_id"
        case videoTaskID = "video_task_id"
        case editorID = "editor_id"
        case taskCreated = "task_created"
        case taskStatus = "task_status"
        case airDate = "air_date"
    }

    var result: ContentPlanAssignEditorResult {
        ContentPlanAssignEditorResult(
            contentPlanID: contentPlanID,
            videoTaskID: videoTaskID,
            editorID: editorID,
            taskCreated: taskCreated,
            taskStatus: taskStatus,
            airDate: airDate
        )
    }
}

private struct ContentPlanEditorIdentityDTO: Decodable {
    var id: UUID
}

private struct ContentPlanOneOrMany<Element: Decodable>: Decodable {
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

private func normalizedContentPlanColor(_ value: String?, fallbackSeed: String) -> String {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          value.range(of: #"^#[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil else {
        let palette = ["#0EA5E9", "#22C55E", "#F59E0B", "#EF4444", "#14B8A6", "#8B5CF6", "#EC4899"]
        let total = fallbackSeed.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[total % palette.count]
    }
    return value.uppercased()
}
