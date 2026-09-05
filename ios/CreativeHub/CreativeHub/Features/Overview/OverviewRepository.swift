import Foundation
import Supabase

protocol OverviewDataProviding: Sendable {
    var usesProductionData: Bool { get }
    func fetchOverviewRawData(month: OverviewMonth) async throws -> OverviewRawData
}

struct OverviewSupabaseRepository: OverviewDataProviding {
    var usesProductionData: Bool { true }

    private let client: SupabaseClient?
    private let pageSize = 1_000

    init(client: SupabaseClient? = SupabaseService.shared.client) {
        self.client = client
    }

    func fetchOverviewRawData(month: OverviewMonth) async throws -> OverviewRawData {
        guard let client else {
            throw OverviewRepositoryError.configurationMissing
        }

        async let tasks = fetchVideoTasks(client: client)
        async let shoots = fetchShoots(client: client, month: month)
        async let editors = fetchEditors(client: client)

        return try await OverviewRawData(tasks: tasks, shoots: shoots, editors: editors)
    }

    private func fetchVideoTasks(client: SupabaseClient) async throws -> [OverviewTaskRow] {
        var rows: [OverviewVideoTaskDTO] = []
        var offset = 0

        while true {
            let page: [OverviewVideoTaskDTO] = try await client
                .from("video_tasks")
                .select("""
                    id,
                    title,
                    resize_reqs,
                    editor_id,
                    order_team,
                    category,
                    receive_date,
                    return_date,
                    air_date,
                    status,
                    result_link,
                    content_plan_id,
                    content_plan:content_plan_id (
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
                """)
                .order("air_date", ascending: true, nullsFirst: false)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value

            rows.append(contentsOf: page)
            guard page.count == pageSize else { break }
            offset += pageSize
        }

        return rows.map(\.overviewRow)
    }

    private func fetchShoots(client: SupabaseClient, month: OverviewMonth) async throws -> [OverviewShootRow] {
        var rows: [OverviewShootDTO] = []
        var offset = 0

        while true {
            let page: [OverviewShootDTO] = try await client
                .from("shoots")
                .select("""
                    id,
                    shoot_date,
                    shoot_type,
                    shoot_editors (
                        profile_id,
                        profiles!shoot_editors_profile_id_fkey (
                            id,
                            editor_code
                        )
                    )
                """)
                .gte("shoot_date", value: month.startISODate)
                .lte("shoot_date", value: month.endISODate)
                .order("shoot_date", ascending: true)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value

            rows.append(contentsOf: page)
            guard page.count == pageSize else { break }
            offset += pageSize
        }

        return rows.map(\.overviewRow)
    }

    private func fetchEditors(client: SupabaseClient) async throws -> [OverviewEditorRow] {
        var rows: [OverviewProfileDTO] = []
        var offset = 0

        while true {
            let page: [OverviewProfileDTO] = try await client
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
                .neq("is_active", value: false)
                .order("role", ascending: true)
                .order("short_name", ascending: true)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value

            rows.append(contentsOf: page)
            guard page.count == pageSize else { break }
            offset += pageSize
        }

        return rows.compactMap(\.overviewEditor)
    }
}

enum OverviewRepositoryError: Error, Equatable {
    case configurationMissing
}

#if DEBUG
struct OverviewFixtureProvider: OverviewDataProviding {
    enum Fixture: Equatable {
        case visual
        case zero
        case error
    }

    var fixture: Fixture
    var usesProductionData: Bool { false }

    func fetchOverviewRawData(month: OverviewMonth) async throws -> OverviewRawData {
        switch fixture {
        case .visual:
            return .phase4VisualFixture(month: month)
        case .zero:
            return OverviewRawData(tasks: [], shoots: [], editors: [])
        case .error:
            throw OverviewRepositoryError.configurationMissing
        }
    }
}
#endif

private struct OverviewVideoTaskDTO: Decodable {
    var id: String
    var title: String?
    var resizeRequirements: String?
    var orderTeam: String?
    var category: String?
    var receiveDate: String?
    var returnDate: String?
    var airDate: String?
    var status: String?
    var resultLink: String?
    var contentPlanID: String?
    var contentPlan: OneOrMany<OverviewContentPlanDTO>?
    var profiles: OneOrMany<OverviewProfileDTO>?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case resizeRequirements = "resize_reqs"
        case orderTeam = "order_team"
        case category
        case receiveDate = "receive_date"
        case returnDate = "return_date"
        case airDate = "air_date"
        case status
        case resultLink = "result_link"
        case contentPlanID = "content_plan_id"
        case contentPlan = "content_plan"
        case profiles
    }

    var overviewRow: OverviewTaskRow {
        let linkedPlan = contentPlan?.first
        let profile = linkedPlan?.profiles?.first ?? profiles?.first
        return OverviewTaskRow(
            id: id,
            title: title ?? "",
            orderTeam: orderTeam ?? "",
            category: category ?? "",
            status: status ?? "Chờ",
            resizeRequirements: resizeRequirements ?? "",
            receiveDate: receiveDate,
            returnDate: returnDate,
            airDate: airDate,
            linkedAirDate: contentPlanID == nil ? nil : linkedPlan?.airDate,
            resultLink: resultLink ?? "",
            editorCode: profile?.editorCode ?? "",
            editorProfileID: profile?.id
        )
    }
}

private struct OverviewContentPlanDTO: Decodable {
    var airDate: String?
    var editorID: String?
    var profiles: OneOrMany<OverviewProfileDTO>?

    enum CodingKeys: String, CodingKey {
        case airDate = "air_date"
        case editorID = "editor_id"
        case profiles
    }
}

private struct OverviewShootDTO: Decodable {
    var id: String
    var shootDate: String
    var shootType: String
    var shootEditors: [OverviewShootEditorDTO]?

    enum CodingKeys: String, CodingKey {
        case id
        case shootDate = "shoot_date"
        case shootType = "shoot_type"
        case shootEditors = "shoot_editors"
    }

    var overviewRow: OverviewShootRow {
        let profiles = (shootEditors ?? []).compactMap { $0.profiles?.first }
        return OverviewShootRow(
            id: id,
            shootDate: shootDate,
            type: shootType,
            editorCodes: profiles.compactMap { $0.editorCode?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() },
            editorProfileIDs: profiles.map(\.id)
        )
    }
}

private struct OverviewShootEditorDTO: Decodable {
    var profileID: String
    var profiles: OneOrMany<OverviewProfileDTO>?

    enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
        case profiles
    }
}

private struct OverviewProfileDTO: Decodable {
    var id: String
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

    var overviewEditor: OverviewEditorRow? {
        guard let code = editorCode?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !code.isEmpty else {
            return nil
        }
        if (isActive ?? active ?? true) == false { return nil }
        if isEditorMember == false { return nil }

        let name = fullName.nonEmpty ?? displayName.nonEmpty ?? shortName.nonEmpty ?? code.uppercased()
        let short = shortName.nonEmpty ?? displayName.nonEmpty ?? name
        return OverviewEditorRow(
            id: id,
            editorCode: code,
            name: name,
            shortName: short,
            initials: String(short.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased(),
            avatarURL: avatarURL.nonEmpty.flatMap(URL.init(string:)),
            colorHex: normalizedColor(uiColor, fallbackSeed: code)
        )
    }
}

private struct OneOrMany<Element: Decodable>: Decodable {
    var values: [Element]

    var first: Element? {
        values.first
    }

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

private func normalizedColor(_ value: String?, fallbackSeed: String) -> String {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), value.range(of: #"^#[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil else {
        return OverviewAggregator.fallbackColor(seed: fallbackSeed)
    }
    return value.uppercased()
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}
