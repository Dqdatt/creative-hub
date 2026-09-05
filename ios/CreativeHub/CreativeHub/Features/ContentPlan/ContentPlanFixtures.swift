#if DEBUG
import Foundation

actor ContentPlanFixtureProvider: ContentPlanDataProviding {
    enum Mode {
        case full
        case empty
        case error
    }

    nonisolated var usesProductionData: Bool { false }

    private var mode: Mode
    private var items: [ContentPlanItem]
    private let editors: [ContentPlanEditorOption]

    init(mode: Mode) {
        self.mode = mode
        self.editors = Self.makeEditors()
        self.items = mode == .empty ? [] : Self.makeItems(editors: editors)
    }

    func fetchItems(monthValue: String) async throws -> [ContentPlanItem] {
        if mode == .error { throw ContentPlanRepositoryError.backend("Fixture Content Plan lỗi tải.") }
        let range = ContentPlanDateFormatter.monthRange(monthValue)
        return items
            .filter { $0.airDate >= range.start && $0.airDate <= range.end }
            .sorted(by: ContentPlanSorter.areInIncreasingOrder)
    }

    func fetchEditorOptions() async throws -> [ContentPlanEditorOption] {
        if mode == .error { throw ContentPlanRepositoryError.backend("Fixture editor lỗi tải.") }
        return editors
    }

    func createItem(_ data: ContentPlanFormData, userID: UUID?) async throws {
        let payload = try ContentPlanPayload(data: data, includeEditor: false)
        let item = ContentPlanItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000007f0")!,
            airDate: payload.airDate,
            title: payload.title,
            note: payload.note ?? "",
            category: ContentPlanCategory(rawValue: payload.category),
            editorCode: "",
            editorProfileID: nil,
            editorDisplayName: "Chưa phân công",
            link: payload.link ?? "",
            linkedVideoTaskID: nil,
            linkedTaskStatus: nil
        )
        items.append(item)
    }

    func updateItem(id: UUID, data: ContentPlanFormData, previousItem: ContentPlanItem, userID: UUID?) async throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw ContentPlanRepositoryError.backend("Không tìm thấy Content Plan.")
        }
        let payload = try ContentPlanPayload(data: data, includeEditor: false)
        items[index].airDate = payload.airDate
        items[index].title = payload.title
        items[index].note = payload.note ?? ""
        items[index].category = ContentPlanCategory(rawValue: payload.category)
        if !items[index].hasLinkedTask {
            items[index].link = payload.link ?? ""
        }
    }

    func assignEditor(id: UUID, editorCode: String) async throws -> ContentPlanAssignEditorResult {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw ContentPlanRepositoryError.backend("Không tìm thấy Content Plan.")
        }
        let clean = editorCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let editor = editors.first { $0.editorCode == clean }
        guard items[index].category.canCreateVideoTask else {
            throw ContentPlanRepositoryError.backend("Thể loại Content Plan chưa tương thích với Video tháng.")
        }
        if items[index].isLinkedTaskStarted, editor?.editorCode != items[index].editorCode {
            throw ContentPlanRepositoryError.backend("Không thể đổi Editor vì Task đã được bắt đầu.")
        }
        if let editor {
            items[index].editorCode = editor.editorCode
            items[index].editorProfileID = editor.profileID
            items[index].editorDisplayName = editor.shortName
        } else {
            items[index].editorCode = ""
            items[index].editorProfileID = nil
            items[index].editorDisplayName = "Chưa phân công"
        }
        let created = items[index].linkedVideoTaskID == nil && editor != nil
        if created {
            items[index].linkedVideoTaskID = UUID(uuidString: "00000000-0000-0000-0000-0000000007ff")
            items[index].linkedTaskStatus = "Chờ"
        }
        return ContentPlanAssignEditorResult(
            contentPlanID: id,
            videoTaskID: items[index].linkedVideoTaskID,
            editorID: items[index].editorProfileID,
            taskCreated: created,
            taskStatus: items[index].linkedTaskStatus,
            airDate: items[index].airDate
        )
    }

    func deleteItem(id: UUID) async throws {
        items.removeAll { $0.id == id }
    }

    private static func makeEditors() -> [ContentPlanEditorOption] {
        [
            ContentPlanEditorOption(editorCode: "dat", profileID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, name: "Đoàn Quốc Đạt", shortName: "Đạt Đoàn", initials: "Đ", colorHex: "#0EA5E9", avatarURL: nil, role: "admin"),
            ContentPlanEditorOption(editorCode: "hai", profileID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, name: "Nguyễn Thanh Hải", shortName: "Thanh Hải", initials: "H", colorHex: "#22C55E", avatarURL: nil, role: "editor"),
            ContentPlanEditorOption(editorCode: "minh", profileID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, name: "Hoàng Hữu Lê Minh", shortName: "Hữu Minh", initials: "M", colorHex: "#F59E0B", avatarURL: nil, role: "editor")
        ]
    }

    private static func makeItems(editors: [ContentPlanEditorOption]) -> [ContentPlanItem] {
        let dat = editors[0]
        let hai = editors[1]
        let minh = editors[2]
        return [
            item("00000000-0000-0000-0000-000000000701", "2026-08-01", "Video khai trương showroom Cần Thơ", "Brief đã duyệt, chờ phân công dựng.", .longForm, nil, "", nil, nil),
            item("00000000-0000-0000-0000-000000000702", "2026-08-02", "Motion ưu đãi nệm tháng 8", "Cần bản motion 1x1 cho Digital.", .motion, minh, "", UUID(uuidString: "00000000-0000-0000-0000-000000000604"), "Đang làm"),
            item("00000000-0000-0000-0000-000000000703", "2026-08-03", "Ảnh sản phẩm drap mới phông trắng", "Không tạo Video Task vì là category Ảnh.", .image, nil, "", nil, nil),
            item("00000000-0000-0000-0000-000000000704", "2026-08-05", "Short review IKI Premium cho TikTok", "Short/Reels chưa tương thích Video tháng.", .shortReels, hai, "", nil, nil),
            item("00000000-0000-0000-0000-000000000705", "2026-08-07", "Ads remarketing Cocoon Grey", "Đã sinh task và chờ editor nhận.", .ads, hai, "", UUID(uuidString: "00000000-0000-0000-0000-000000000606"), "Chờ"),
            item("00000000-0000-0000-0000-000000000706", "2026-08-09", "Livestream combo phòng ngủ mùa mưa", "Livestream không tương thích Video tháng.", .livestream, nil, "", nil, nil),
            item("00000000-0000-0000-0000-000000000707", "2026-08-12", "Video hoàn thành từ Content Plan", "Link đồng bộ từ Video tháng.", .longForm, dat, "https://example.com/content-plan/done", UUID(uuidString: "00000000-0000-0000-0000-000000000601"), "Đã xong"),
            item("00000000-0000-0000-0000-000000000708", "2026-08-20", "Video cuối tháng an toàn scroll", "Dòng cuối dùng cho QA bottom scroll.", .longForm, nil, "", nil, nil)
        ]
    }

    private static func item(_ id: String, _ airDate: String, _ title: String, _ note: String, _ category: ContentPlanCategory, _ editor: ContentPlanEditorOption?, _ link: String, _ linkedTaskID: UUID?, _ linkedTaskStatus: String?) -> ContentPlanItem {
        ContentPlanItem(
            id: UUID(uuidString: id)!,
            airDate: airDate,
            title: title,
            note: note,
            category: category,
            editorCode: editor?.editorCode ?? "",
            editorProfileID: editor?.profileID,
            editorDisplayName: editor?.shortName ?? "Chưa phân công",
            link: link,
            linkedVideoTaskID: linkedTaskID,
            linkedTaskStatus: linkedTaskStatus
        )
    }
}
#endif
