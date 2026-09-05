#if DEBUG
import Foundation

enum CalendarFixtureMode: String {
    case full
    case empty
    case error
    case readonly
    case filterEmpty = "filter-empty"
}

actor CalendarFixtureProvider: CalendarDataProviding {
    nonisolated var usesProductionData: Bool { false }

    private let mode: CalendarFixtureMode
    private var shoots: [CalendarShoot]
    private let editors: [CalendarEditorOption]

    init(mode: CalendarFixtureMode) {
        self.mode = mode
        editors = CalendarFixtureProvider.makeEditors()
        switch mode {
        case .empty:
            shoots = []
        case .filterEmpty:
            shoots = CalendarFixtureProvider.makeShoots().filter { $0.type != .other }
        case .error:
            shoots = []
        case .full, .readonly:
            shoots = CalendarFixtureProvider.makeShoots()
        }
    }

    func fetchShoots(startDate: String, endDate: String) async throws -> [CalendarShoot] {
        if mode == .error {
            throw CalendarRepositoryError.backend("Không thể tải lịch quay. Vui lòng thử lại.")
        }
        return shoots
            .filter {
                let iso = CalendarDateFormatter.isoString(from: $0.date)
                return iso >= startDate && iso <= endDate
            }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date { return lhs.id.uuidString < rhs.id.uuidString }
                return lhs.date < rhs.date
            }
    }

    func fetchEditorOptions() async throws -> [CalendarEditorOption] {
        if mode == .error {
            throw CalendarRepositoryError.backend("Không thể tải lịch quay. Vui lòng thử lại.")
        }
        return editors
    }

    func createShoot(_ data: CalendarFormData) async throws {
        let payload = try CalendarPayload(data: data)
        let date = CalendarDateFormatter.date(from: payload.shootDate) ?? Date()
        let selectedEditors = editors.filter { data.editorCodes.contains($0.editorCode) }
        let labels = selectedEditors.map(CalendarEditorCrewLabelMapper.label(for:))
        shoots.append(CalendarShoot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000099") ?? UUID(),
            date: date,
            type: data.type,
            crew: data.crew,
            editorCodes: data.editorCodes,
            editorProfileIDs: selectedEditors.map(\.profileID),
            editorLabels: labels,
            displayCrew: CalendarEditorCrewLabelMapper.combine(editorLabels: labels, crew: data.crew),
            place: data.place,
            content: data.content,
            time: data.time,
            note: data.note
        ))
    }

    func updateShoot(id: UUID, data: CalendarFormData) async throws {
        _ = try CalendarPayload(data: data)
        guard let index = shoots.firstIndex(where: { $0.id == id }) else {
            throw CalendarRepositoryError.backend("Không tìm thấy lịch quay.")
        }
        let selectedEditors = editors.filter { data.editorCodes.contains($0.editorCode) }
        let labels = selectedEditors.map(CalendarEditorCrewLabelMapper.label(for:))
        shoots[index].date = CalendarDateFormatter.date(from: data.date) ?? shoots[index].date
        shoots[index].type = data.type
        shoots[index].time = data.time
        shoots[index].place = data.place
        shoots[index].editorCodes = data.editorCodes
        shoots[index].editorProfileIDs = selectedEditors.map(\.profileID)
        shoots[index].editorLabels = labels
        shoots[index].crew = data.crew
        shoots[index].displayCrew = CalendarEditorCrewLabelMapper.combine(editorLabels: labels, crew: data.crew)
        shoots[index].content = data.content
        shoots[index].note = data.note
    }

    func deleteShoot(id: UUID) async throws {
        shoots.removeAll { $0.id == id }
    }

    private static func makeEditors() -> [CalendarEditorOption] {
        [
            CalendarEditorOption(
                editorCode: "dat",
                profileID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                name: "Đoàn Quốc Đạt",
                shortName: "Đạt Đoàn",
                initials: "Đ",
                colorHex: "#0EA5E9",
                avatarURL: nil
            ),
            CalendarEditorOption(
                editorCode: "minh",
                profileID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                name: "Hữu Minh",
                shortName: "Hữu Minh",
                initials: "M",
                colorHex: "#F59E0B",
                avatarURL: nil
            ),
            CalendarEditorOption(
                editorCode: "hai",
                profileID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                name: "Thanh Hải",
                shortName: "Thanh Hải",
                initials: "H",
                colorHex: "#22C55E",
                avatarURL: nil
            )
        ]
    }

    private static func makeShoots() -> [CalendarShoot] {
        [
            shoot("00000000-0000-0000-0000-000000000001", "2026-08-03", .livestream, ["dat"], ["ĐẠT"], "KHANG", "Livestream Shopee khung tối", "LIVESTREAM SHOPEE", "BUỔI TỐI"),
            shoot("00000000-0000-0000-0000-000000000002", "2026-08-05", .lichquay, ["dat", "minh"], ["ĐẠT", "MINH"], "BUMI", "Kịch bản showroom Hòa Bình - hiểu đúng nệm", "SHOWROOM HÒA BÌNH", "ALL MORNING"),
            shoot("00000000-0000-0000-0000-000000000003", "2026-08-12", .onset, ["hai"], ["HẢI"], "BÙI", "On set TIDO quay hậu trường ra mắt sản phẩm mới", "ON SET TIDO", "13:30"),
            shoot("00000000-0000-0000-0000-000000000004", "2026-08-18", .other, ["minh"], ["MINH"], "MY", "Chụp ảnh nội bộ CreativeHub cho bộ nhận diện mùa mới", "Studio Bà Hom với tên địa điểm rất dài để kiểm tra cắt dòng", ""),
            shoot("00000000-0000-0000-0000-000000000005", "2026-08-24", .lichquay, ["dat", "hai"], ["ĐẠT", "HẢI"], "LINH - BUMI", "Drap mới phông trắng / content tháng 9", "SHOWROOM AN SƯƠNG", "ALL MORNING")
        ]
    }

    private static func shoot(
        _ id: String,
        _ isoDate: String,
        _ type: CalendarShootType,
        _ editorCodes: [String],
        _ editorLabels: [String],
        _ crew: String,
        _ content: String,
        _ place: String,
        _ time: String
    ) -> CalendarShoot {
        CalendarShoot(
            id: UUID(uuidString: id)!,
            date: CalendarDateFormatter.date(from: isoDate)!,
            type: type,
            crew: crew,
            editorCodes: editorCodes,
            editorProfileIDs: [],
            editorLabels: editorLabels,
            displayCrew: CalendarEditorCrewLabelMapper.combine(editorLabels: editorLabels, crew: crew),
            place: place,
            content: content,
            time: time,
            note: "Ghi chú QA"
        )
    }

}
#endif
