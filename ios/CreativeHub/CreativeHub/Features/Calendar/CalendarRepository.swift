import Foundation
import Supabase

protocol CalendarDataProviding: Sendable {
    var usesProductionData: Bool { get }
    func fetchShoots(startDate: String, endDate: String) async throws -> [CalendarShoot]
    func fetchEditorOptions() async throws -> [CalendarEditorOption]
    func createShoot(_ data: CalendarFormData) async throws
    func updateShoot(id: UUID, data: CalendarFormData) async throws
    func deleteShoot(id: UUID) async throws
}

struct CalendarSupabaseRepository: CalendarDataProviding {
    var usesProductionData: Bool { true }

    private let client: SupabaseClient?

    init(client: SupabaseClient? = SupabaseService.shared.client) {
        self.client = client
    }

    func fetchShoots(startDate: String, endDate: String) async throws -> [CalendarShoot] {
        guard let client else { throw CalendarRepositoryError.configurationMissing }
        let rows: [CalendarShootDTO] = try await client
            .from("shoots")
            .select("""
                id,
                shoot_date,
                shoot_type,
                crew,
                time_slot,
                location,
                content_note,
                shoot_note,
                shoot_editors (
                    profile_id,
                    profiles!shoot_editors_profile_id_fkey (
                        id,
                        editor_code,
                        short_name,
                        display_name,
                        full_name,
                        ui_color
                    )
                )
            """)
            .gte("shoot_date", value: startDate)
            .lte("shoot_date", value: endDate)
            .order("shoot_date", ascending: true)
            .order("created_at", ascending: true)
            .execute()
            .value
        return rows.compactMap(\.shoot)
    }

    func fetchEditorOptions() async throws -> [CalendarEditorOption] {
        guard let client else { throw CalendarRepositoryError.configurationMissing }
        let rows: [CalendarEditorOptionDTO] = try await client
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
        return rows.compactMap(\.option).sorted { lhs, rhs in
            if lhs.name == rhs.name {
                return lhs.editorCode < rhs.editorCode
            }
            return lhs.shortName.localizedCompare(rhs.shortName) == .orderedAscending
        }
    }

    func createShoot(_ data: CalendarFormData) async throws {
        guard let client else { throw CalendarRepositoryError.configurationMissing }
        let payload = try CalendarPayload(data: data)
        let result: [CalendarCreateResultDTO] = try await client
            .rpc("create_shoot_with_notifications", params: CalendarCreateRPCParams(payload: payload, editorCodes: data.editorCodes))
            .execute()
            .value
        guard let id = result.first?.shootID else {
            throw CalendarRepositoryError.backend("Không nhận được mã lịch quay. Vui lòng thử lại.")
        }
        try await updateShootNote(id: id, note: payload.shootNote)
    }

    func updateShoot(id: UUID, data: CalendarFormData) async throws {
        guard let client else { throw CalendarRepositoryError.configurationMissing }
        let payload = try CalendarPayload(data: data)
        _ = try await client
            .rpc("update_shoot_with_notifications", params: CalendarUpdateRPCParams(shootID: id, payload: payload, editorCodes: data.editorCodes))
            .execute()
        try await updateShootNote(id: id, note: payload.shootNote)
    }

    func deleteShoot(id: UUID) async throws {
        guard let client else { throw CalendarRepositoryError.configurationMissing }
        _ = try await client
            .rpc("delete_shoot_with_notifications", params: CalendarDeleteRPCParams(shootID: id))
            .execute()
    }

    private func updateShootNote(id: UUID, note: String?) async throws {
        guard let client else { throw CalendarRepositoryError.configurationMissing }
        _ = try await client
            .from("shoots")
            .update(CalendarShootNotePatch(shootNote: note))
            .eq("id", value: id)
            .execute()
    }
}

struct CalendarPayload: Equatable, Sendable {
    var shootDate: String
    var shootType: CalendarShootType
    var crew: String?
    var timeSlot: String?
    var location: String
    var contentNote: String
    var shootNote: String?

    init(data: CalendarFormData) throws {
        let date = data.date.trimmingCharacters(in: .whitespacesAndNewlines)
        guard CalendarDateFormatter.isValidISODate(date) else {
            throw CalendarValidationError.invalidDate
        }
        let location = data.place.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !location.isEmpty else {
            throw CalendarValidationError.missingPlace
        }
        let content = data.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            throw CalendarValidationError.missingContent
        }

        shootDate = date
        shootType = data.type
        crew = data.crew.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        timeSlot = data.time.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.location = location
        contentNote = content
        shootNote = data.note.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

enum CalendarRPCContract {
    static func createParams(data: CalendarFormData) throws -> [String: String] {
        let payload = try CalendarPayload(data: data)
        var params = baseParams(payload: payload)
        params["p_editor_codes"] = normalizedEditorCodes(data.editorCodes).joined(separator: ",")
        return params
    }

    static func updateParams(id: UUID, data: CalendarFormData) throws -> [String: String] {
        let payload = try CalendarPayload(data: data)
        var params = baseParams(payload: payload)
        params["p_shoot_id"] = id.uuidString
        params["p_editor_codes"] = normalizedEditorCodes(data.editorCodes).joined(separator: ",")
        return params
    }

    static func deleteParams(id: UUID) -> [String: String] {
        ["p_shoot_id": id.uuidString]
    }

    static func normalizedEditorCodes(_ values: [String]) -> [String] {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    private static func baseParams(payload: CalendarPayload) -> [String: String] {
        [
            "p_shoot_date": payload.shootDate,
            "p_shoot_type": payload.shootType.rawValue,
            "p_crew": payload.crew ?? "",
            "p_time_slot": payload.timeSlot ?? "",
            "p_location": payload.location,
            "p_content_note": payload.contentNote
        ]
    }
}

private struct CalendarCreateRPCParams: Encodable {
    var pShootDate: String
    var pShootType: String
    var pCrew: String?
    var pTimeSlot: String?
    var pLocation: String
    var pContentNote: String
    var pEditorCodes: [String]

    init(payload: CalendarPayload, editorCodes: [String]) {
        pShootDate = payload.shootDate
        pShootType = payload.shootType.rawValue
        pCrew = payload.crew
        pTimeSlot = payload.timeSlot
        pLocation = payload.location
        pContentNote = payload.contentNote
        pEditorCodes = editorCodes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty }
    }

    enum CodingKeys: String, CodingKey {
        case pShootDate = "p_shoot_date"
        case pShootType = "p_shoot_type"
        case pCrew = "p_crew"
        case pTimeSlot = "p_time_slot"
        case pLocation = "p_location"
        case pContentNote = "p_content_note"
        case pEditorCodes = "p_editor_codes"
    }
}

private struct CalendarUpdateRPCParams: Encodable {
    var pShootID: UUID
    var pShootDate: String
    var pShootType: String
    var pCrew: String?
    var pTimeSlot: String?
    var pLocation: String
    var pContentNote: String
    var pEditorCodes: [String]

    init(shootID: UUID, payload: CalendarPayload, editorCodes: [String]) {
        pShootID = shootID
        pShootDate = payload.shootDate
        pShootType = payload.shootType.rawValue
        pCrew = payload.crew
        pTimeSlot = payload.timeSlot
        pLocation = payload.location
        pContentNote = payload.contentNote
        pEditorCodes = editorCodes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty }
    }

    enum CodingKeys: String, CodingKey {
        case pShootID = "p_shoot_id"
        case pShootDate = "p_shoot_date"
        case pShootType = "p_shoot_type"
        case pCrew = "p_crew"
        case pTimeSlot = "p_time_slot"
        case pLocation = "p_location"
        case pContentNote = "p_content_note"
        case pEditorCodes = "p_editor_codes"
    }
}

private struct CalendarDeleteRPCParams: Encodable {
    var pShootID: UUID

    init(shootID: UUID) {
        pShootID = shootID
    }

    enum CodingKeys: String, CodingKey {
        case pShootID = "p_shoot_id"
    }
}

private struct CalendarShootNotePatch: Encodable {
    var shootNote: String?

    enum CodingKeys: String, CodingKey {
        case shootNote = "shoot_note"
    }
}

private struct CalendarCreateResultDTO: Decodable {
    var shootID: UUID

    enum CodingKeys: String, CodingKey {
        case shootID = "shoot_id"
    }
}

private struct CalendarShootDTO: Decodable {
    var id: UUID
    var shootDate: String
    var shootType: String
    var crew: String?
    var timeSlot: String?
    var location: String?
    var contentNote: String?
    var shootNote: String?
    var shootEditors: [CalendarShootEditorDTO]?

    enum CodingKeys: String, CodingKey {
        case id
        case shootDate = "shoot_date"
        case shootType = "shoot_type"
        case crew
        case timeSlot = "time_slot"
        case location
        case contentNote = "content_note"
        case shootNote = "shoot_note"
        case shootEditors = "shoot_editors"
    }

    var shoot: CalendarShoot? {
        guard let date = CalendarDateFormatter.date(from: shootDate),
              let type = CalendarShootType(rawValue: shootType) else {
            return nil
        }
        let editors = (shootEditors ?? []).compactMap(\.editor)
        let labels = editors.map(\.label)
        let crewValue = crew ?? ""
        return CalendarShoot(
            id: id,
            date: date,
            type: type,
            crew: crewValue,
            editorCodes: editors.map(\.editorCode),
            editorProfileIDs: editors.map(\.profileID),
            editorLabels: labels,
            displayCrew: CalendarEditorCrewLabelMapper.combine(editorLabels: labels, crew: crewValue),
            place: location ?? "",
            content: contentNote ?? "",
            time: timeSlot ?? "",
            note: shootNote ?? ""
        )
    }

}

private struct CalendarShootEditorDTO: Decodable {
    var profileID: UUID
    var profiles: CalendarProfileDTO?

    enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
        case profiles
    }

    var editor: CalendarShootEditor? {
        guard let profile = profiles,
              let editorCode = profile.editorCode?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !editorCode.isEmpty else {
            return nil
        }
        return CalendarShootEditor(editorCode: editorCode, profileID: profileID, label: profile.crewLabel)
    }
}

private struct CalendarEditorOptionDTO: Decodable {
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

    var option: CalendarEditorOption? {
        guard let code = editorCode?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !code.isEmpty,
              isEditorMember == true,
              (isActive ?? active ?? true) != false else {
            return nil
        }
        let name = fullName.nilIfEmpty ?? displayName.nilIfEmpty ?? shortName.nilIfEmpty ?? code
        let short = shortName.nilIfEmpty ?? displayName.nilIfEmpty ?? name
        return CalendarEditorOption(
            editorCode: code,
            profileID: id,
            name: name,
            shortName: short,
            initials: CalendarProfileDTO.initial(from: short),
            colorHex: CalendarProfileDTO.validColor(uiColor) ?? CalendarProfileDTO.fallbackColor(seed: code),
            avatarURL: avatarURL.nilIfEmpty.flatMap(URL.init(string:))
        )
    }
}

private struct CalendarProfileDTO: Decodable {
    var id: UUID?
    var editorCode: String?
    var shortName: String?
    var displayName: String?
    var fullName: String?
    var uiColor: String?

    enum CodingKeys: String, CodingKey {
        case id
        case editorCode = "editor_code"
        case shortName = "short_name"
        case displayName = "display_name"
        case fullName = "full_name"
        case uiColor = "ui_color"
    }

    var crewLabel: String {
        CalendarEditorCrewLabelMapper.label(
            editorCode: editorCode,
            fullName: fullName,
            displayName: displayName,
            shortName: shortName
        )
    }

    static func initial(from value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "E"
    }

    static func validColor(_ value: String?) -> String? {
        guard let value, value.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil else {
            return nil
        }
        return value
    }

    static func fallbackColor(seed: String) -> String {
        let palette = ["#0EA5E9", "#22C55E", "#F59E0B", "#EF4444", "#14B8A6", "#8B5CF6", "#EC4899"]
        let total = seed.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[total % palette.count]
    }
}

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

private extension String {
    var nilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
