import Foundation

#if DEBUG
final class VideoTaskFixtureProvider: VideoTaskDataProviding, @unchecked Sendable {
    enum Mode: Equatable {
        case full
        case empty
        case error
    }

    var usesProductionData: Bool { false }
    private let mode: Mode
    private var tasks: [VideoTask]
    private let editors: [VideoTaskEditorOption]

    init(mode: Mode) {
        self.mode = mode
        self.editors = Self.makeEditors()
        self.tasks = Self.makeTasks(editors: editors)
    }

    func fetchTasks(monthValue: String) async throws -> [VideoTask] {
        if mode == .error {
            throw VideoTaskRepositoryError.backend("Không thể tải danh sách video.")
        }
        if mode == .empty {
            return []
        }
        let range = VideoTaskDateFormatter.monthRange(monthValue)
        return tasks
            .filter { task in
                guard let air = task.airDate else { return false }
                return air >= range.start && air <= range.end
            }
            .sorted { lhs, rhs in
                if (lhs.airDate ?? "") == (rhs.airDate ?? "") {
                    return lhs.sequence < rhs.sequence
                }
                return (lhs.airDate ?? "9999-12-31") < (rhs.airDate ?? "9999-12-31")
            }
            .enumerated()
            .map { index, task in
                var copy = task
                copy.sequence = index + 1
                return copy
            }
    }

    func fetchEditorOptions() async throws -> [VideoTaskEditorOption] {
        if mode == .error {
            throw VideoTaskRepositoryError.backend("Không thể tải danh sách video.")
        }
        return editors
    }

    func createTask(_ data: VideoTaskFormData, userID: UUID?) async throws {
        _ = try await VideoTaskPayload.make(data: data)
        let editor = editors.first { $0.editorCode == data.editorCode }
        tasks.append(VideoTask(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000699")!,
            contentPlanID: nil,
            sequence: tasks.count + 1,
            title: data.title.trimmingCharacters(in: .whitespacesAndNewlines),
            resize: data.resize,
            editorCode: data.editorCode,
            editorProfileID: editor?.profileID,
            editorDisplayName: editor?.shortName ?? "Chưa phân công",
            orderTeam: data.orderTeam,
            category: data.category,
            receiveDate: data.receiveDate.videoNilIfEmpty,
            returnDate: data.returnDate.videoNilIfEmpty,
            airDate: data.airDate.videoNilIfEmpty,
            status: data.status,
            priority: data.priority,
            resultLink: data.resultLink,
            note: data.note
        ))
    }

    func updateTask(id: UUID, data: VideoTaskFormData, previousTask: VideoTask, userID: UUID?, allowLinkedOverride: Bool) async throws {
        _ = try await VideoTaskPayload.make(data: data)
        guard let index = tasks.firstIndex(where: { $0.id == id }) else {
            throw VideoTaskRepositoryError.backend("Không tìm thấy Task.")
        }
        if tasks[index].isLinked && !allowLinkedOverride {
            throw VideoTaskRepositoryError.backend("Task liên kết cần dùng luồng thao tác riêng.")
        }
        let editor = editors.first { $0.editorCode == data.editorCode }
        tasks[index].title = tasks[index].isLinked ? tasks[index].title : data.title
        tasks[index].resize = data.resize
        tasks[index].editorCode = tasks[index].isLinked ? tasks[index].editorCode : data.editorCode
        tasks[index].editorProfileID = tasks[index].isLinked ? tasks[index].editorProfileID : editor?.profileID
        tasks[index].editorDisplayName = tasks[index].isLinked ? tasks[index].editorDisplayName : editor?.shortName ?? "Chưa phân công"
        tasks[index].orderTeam = data.orderTeam
        tasks[index].category = tasks[index].isLinked ? tasks[index].category : data.category
        tasks[index].receiveDate = data.receiveDate.videoNilIfEmpty
        tasks[index].returnDate = data.returnDate.videoNilIfEmpty
        tasks[index].airDate = tasks[index].isLinked ? tasks[index].airDate : data.airDate.videoNilIfEmpty
        tasks[index].status = data.status
        tasks[index].priority = data.priority
        tasks[index].resultLink = data.resultLink
        tasks[index].note = tasks[index].isLinked ? tasks[index].note : data.note
    }

    func deleteTask(_ task: VideoTask, userID: UUID?) async throws {
        tasks.removeAll { $0.id == task.id }
    }

    func acceptLinkedTask(id: UUID, data: VideoTaskAcceptData) async throws {
        _ = try VideoTaskAcceptPayload(data: data)
        guard let index = tasks.firstIndex(where: { $0.id == id }), tasks[index].isLinked else {
            throw VideoTaskRepositoryError.backend("Không tìm thấy Task.")
        }
        tasks[index].status = .inProgress
        tasks[index].receiveDate = data.receiveDate
        tasks[index].returnDate = data.returnDate
    }

    func updateLinkedExecution(id: UUID, data: VideoTaskExecutionData) async throws {
        _ = try VideoTaskExecutionPayload(data: data)
        guard let index = tasks.firstIndex(where: { $0.id == id }), tasks[index].isLinked else {
            throw VideoTaskRepositoryError.backend("Không tìm thấy Task.")
        }
        tasks[index].orderTeam = data.orderTeam
        tasks[index].priority = data.priority
        tasks[index].resize = data.resize
        tasks[index].receiveDate = data.receiveDate
        tasks[index].returnDate = data.returnDate
        tasks[index].resultLink = data.resultLink
    }

    func completeLinkedTask(id: UUID, resultLink: String) async throws {
        let link = try VideoTaskURLValidator.normalizeRequired(resultLink)
        guard let index = tasks.firstIndex(where: { $0.id == id }), tasks[index].isLinked else {
            throw VideoTaskRepositoryError.backend("Không tìm thấy Task.")
        }
        tasks[index].status = .done
        tasks[index].resultLink = link
    }

    private static func makeEditors() -> [VideoTaskEditorOption] {
        [
            VideoTaskEditorOption(editorCode: "dat", profileID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, name: "Đoàn Quốc Đạt", shortName: "Đạt Đoàn", initials: "Đ", colorHex: "#0EA5E9", avatarURL: nil),
            VideoTaskEditorOption(editorCode: "hai", profileID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, name: "Nguyễn Thanh Hải", shortName: "Thanh Hải", initials: "H", colorHex: "#22C55E", avatarURL: nil),
            VideoTaskEditorOption(editorCode: "minh", profileID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, name: "Hoàng Hữu Lê Minh", shortName: "Hữu Minh", initials: "M", colorHex: "#F59E0B", avatarURL: nil)
        ]
    }

    private static func makeTasks(editors: [VideoTaskEditorOption]) -> [VideoTask] {
        let dat = editors[0]
        let hai = editors[1]
        let minh = editors[2]
        return [
            task("00000000-0000-0000-0000-000000000601", nil, 1, "Video Motion Shopee sale 8.8", "1x1", minh, "ECOM", .motion, "2026-08-01", "2026-08-02", "2026-08-04", .done, .normal, "https://example.com/result/motion", "Đã bàn giao link cho team Digital."),
            task("00000000-0000-0000-0000-000000000602", nil, 2, "Video Review IKI Premium", "9x16 & 1x1", hai, "BRAND", .longForm, "2026-08-02", "2026-08-06", "2026-08-08", .inProgress, .normal, "", "Đang dựng bản cut đầu."),
            task("00000000-0000-0000-0000-000000000603", nil, 3, "Video Ads Cocoon Grey", "9x16", dat, "DIGITAL", .ads, "", "", "2026-08-10", .waiting, .urgent, "", "Cần nhận brief chi tiết."),
            task("00000000-0000-0000-0000-000000000604", UUID(uuidString: "90000000-0000-0000-0000-000000000601"), 4, "CP: Ưu đãi nệm tháng 8", "", dat, "BRAND", .longForm, "", "", "2026-08-12", .waiting, .normal, "", "Nguồn từ Content Plan, chờ editor nhận task."),
            task("00000000-0000-0000-0000-000000000605", UUID(uuidString: "90000000-0000-0000-0000-000000000602"), 5, "CP: Motion BST phòng ngủ", "1x1", dat, "DIGITAL", .motion, "2026-08-05", "2026-08-08", "2026-08-14", .inProgress, .urgent, "", "Linked note từ Content Plan, khóa field kế hoạch."),
            task("00000000-0000-0000-0000-000000000606", UUID(uuidString: "90000000-0000-0000-0000-000000000603"), 6, "CP: Ads remarketing", "9x16", hai, "ECOM", .ads, "2026-08-06", "2026-08-09", "2026-08-16", .done, .normal, "https://example.com/result/ads", "Đã hoàn thành và sync link."),
            task("00000000-0000-0000-0000-000000000607", UUID(uuidString: "90000000-0000-0000-0000-000000000604"), 7, "CP: Video khác editor", "", minh, "HR", .longForm, "", "", "2026-08-18", .waiting, .normal, "", "Không phải task của QA current editor."),
            task("00000000-0000-0000-0000-000000000608", nil, 8, "Video nội bộ tuyển dụng", "", dat, "HR", .longForm, "2026-08-14", "2026-08-20", "2026-08-25", .waiting, .normal, "", "Task thủ công đang chờ xử lý.")
        ]
    }

    private static func task(
        _ id: String,
        _ contentPlanID: UUID?,
        _ sequence: Int,
        _ title: String,
        _ resize: String,
        _ editor: VideoTaskEditorOption,
        _ orderTeam: String,
        _ category: VideoTaskCategory,
        _ receiveDate: String,
        _ returnDate: String,
        _ airDate: String,
        _ status: VideoTaskStatus,
        _ priority: VideoTaskPriority,
        _ resultLink: String,
        _ note: String
    ) -> VideoTask {
        VideoTask(
            id: UUID(uuidString: id)!,
            contentPlanID: contentPlanID,
            sequence: sequence,
            title: title,
            resize: resize,
            editorCode: editor.editorCode,
            editorProfileID: editor.profileID,
            editorDisplayName: editor.shortName,
            orderTeam: orderTeam,
            category: category,
            receiveDate: receiveDate.videoNilIfEmpty,
            returnDate: returnDate.videoNilIfEmpty,
            airDate: airDate.videoNilIfEmpty,
            status: status,
            priority: priority,
            resultLink: resultLink,
            note: note
        )
    }
}
#endif
