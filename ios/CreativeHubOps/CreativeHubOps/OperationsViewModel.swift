import Foundation

@MainActor
final class OperationsViewModel: ObservableObject {
    @Published private(set) var monthRange = AppDateFormatter.currentMonthRange()
    @Published private(set) var tasks: [VideoTask] = []
    @Published private(set) var shoots: [ShootSchedule] = []
    @Published private(set) var contentPlan: [ContentPlanItem] = []
    @Published private(set) var editors: [EditorProfile] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isMutating = false
    @Published var errorMessage: String?
    @Published var selectedTask: VideoTask?
    @Published var selectedShoot: ShootSchedule?
    @Published var selectedContentPlanItem: ContentPlanItem?

    private var repository: OperationsRepositoryServing?
    private var loadGeneration = 0
    private var sessionGeneration = 0

    init(repository: OperationsRepositoryServing? = nil) {
        self.repository = repository
    }

    var dashboardSummary: DashboardSummary {
        DashboardSummary(tasks: tasks, shoots: shoots, editors: editors)
    }

    var isEmpty: Bool {
        tasks.isEmpty && shoots.isEmpty && contentPlan.isEmpty && editors.isEmpty
    }

    func loadCurrentMonth(force: Bool = false) async {
        guard force || (!isLoading && isEmpty) else { return }
        loadGeneration += 1
        let generation = loadGeneration
        let session = sessionGeneration
        let range = monthRange

        isLoading = true
        errorMessage = nil
        defer {
            if isCurrentLoad(generation, session: session) {
                isLoading = false
            }
        }

        do {
            let repository = try makeRepository()
            async let fetchedTasks = repository.fetchVideoTasks(range: range)
            async let fetchedShoots = repository.fetchShoots(range: range)
            async let fetchedContentPlan = repository.fetchContentPlan(range: range)
            async let fetchedEditors = repository.fetchEditors()

            let nextTasks = try await fetchedTasks
            let nextShoots = try await fetchedShoots
            let nextContentPlan = try await fetchedContentPlan
            let nextEditors = try await fetchedEditors
            guard isCurrentLoad(generation, session: session) else { return }

            tasks = nextTasks
            shoots = nextShoots
            contentPlan = nextContentPlan
            editors = nextEditors
        } catch {
            guard isCurrentLoad(generation, session: session) else { return }
            errorMessage = userFacingMessage(for: error)
            tasks = []
            shoots = []
            contentPlan = []
            editors = []
        }
    }

    func refresh() async {
        await loadCurrentMonth(force: true)
    }

    func clearForAccountSwitch() {
        sessionGeneration += 1
        loadGeneration += 1
        tasks = []
        shoots = []
        contentPlan = []
        editors = []
        isLoading = false
        isMutating = false
        errorMessage = nil
        selectedTask = nil
        selectedShoot = nil
        selectedContentPlanItem = nil
    }

    func loadMonth(containing date: Date) async {
        monthRange = AppDateFormatter.monthRange(containing: date)
        await loadCurrentMonth(force: true)
    }

    func moveMonth(by value: Int) async {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let currentStart = formatter.date(from: monthRange.startDate) ?? Date()
        let nextDate = Calendar.current.date(byAdding: .month, value: value, to: currentStart) ?? currentStart
        await loadMonth(containing: nextDate)
    }

    func createVideoTask(_ data: VideoTaskFormData, userId: UUID?) async throws {
        let session = try beginMutation()
        defer { endMutation(session: session) }
        let repository = try makeRepository()
        try await repository.createVideoTask(data, userId: userId)
        guard isCurrentSession(session) else { return }
        await refresh()
    }

    func updateSelectedTask(_ data: VideoTaskFormData, userId: UUID?) async throws {
        let session = try beginMutation()
        defer { endMutation(session: session) }
        guard let selectedTask else {
            throw AppError.notFound("Không tìm thấy task cần cập nhật.")
        }
        let repository = try makeRepository()
        try await repository.updateVideoTask(selectedTask, data: data, userId: userId)
        guard isCurrentSession(session) else { return }
        await refresh()
        guard isCurrentSession(session) else { return }
        self.selectedTask = tasks.first { $0.id == selectedTask.id }
    }

    func deleteSelectedTask() async throws {
        let session = try beginMutation()
        defer { endMutation(session: session) }
        guard let selectedTask else {
            throw AppError.notFound("Không tìm thấy task cần xóa.")
        }
        let repository = try makeRepository()
        try await repository.deleteVideoTask(selectedTask)
        guard isCurrentSession(session) else { return }
        self.selectedTask = nil
        await refresh()
    }

    func acceptSelectedLinkedTask(_ data: LinkedTaskAcceptFormData) async throws {
        let session = try beginMutation()
        defer { endMutation(session: session) }
        guard let selectedTask else {
            throw AppError.notFound("Không tìm thấy task cần nhận.")
        }
        let repository = try makeRepository()
        try await repository.acceptLinkedVideoTask(selectedTask, data: data)
        guard isCurrentSession(session) else { return }
        await refreshLinkedTaskMutation(taskId: selectedTask.id)
    }

    func updateSelectedLinkedTaskExecution(_ data: LinkedTaskExecutionFormData) async throws {
        let session = try beginMutation()
        defer { endMutation(session: session) }
        guard let selectedTask else {
            throw AppError.notFound("Không tìm thấy task cần cập nhật.")
        }
        let repository = try makeRepository()
        try await repository.updateLinkedVideoTaskExecution(selectedTask, data: data)
        guard isCurrentSession(session) else { return }
        await refreshLinkedTaskMutation(taskId: selectedTask.id)
    }

    func completeSelectedLinkedTask(_ data: LinkedTaskExecutionFormData) async throws {
        let session = try beginMutation()
        defer { endMutation(session: session) }
        guard let selectedTask else {
            throw AppError.notFound("Không tìm thấy task cần hoàn thành.")
        }
        let repository = try makeRepository()
        try await repository.completeLinkedVideoTask(selectedTask, data: data)
        guard isCurrentSession(session) else { return }
        await refreshLinkedTaskMutation(taskId: selectedTask.id)
    }

    func createShoot(_ data: ShootFormData) async throws {
        let session = try beginMutation()
        defer { endMutation(session: session) }
        let repository = try makeRepository()
        try await repository.createShoot(data)
        guard isCurrentSession(session) else { return }
        await refresh()
    }

    func updateSelectedShoot(_ data: ShootFormData) async throws {
        let session = try beginMutation()
        defer { endMutation(session: session) }
        guard let selectedShoot else {
            throw AppError.notFound("Không tìm thấy lịch quay cần cập nhật.")
        }
        let repository = try makeRepository()
        try await repository.updateShoot(selectedShoot, data: data)
        guard isCurrentSession(session) else { return }
        await refresh()
        guard isCurrentSession(session) else { return }
        self.selectedShoot = shoots.first { $0.id == selectedShoot.id }
    }

    func deleteSelectedShoot() async throws {
        let session = try beginMutation()
        defer { endMutation(session: session) }
        guard let selectedShoot else {
            throw AppError.notFound("Không tìm thấy lịch quay cần xóa.")
        }
        let repository = try makeRepository()
        try await repository.deleteShoot(selectedShoot)
        guard isCurrentSession(session) else { return }
        self.selectedShoot = nil
        await refresh()
    }

    func createContentPlan(_ data: ContentPlanFormData) async throws {
        let session = try beginMutation()
        defer { endMutation(session: session) }
        let repository = try makeRepository()
        try await repository.createContentPlan(data)
        guard isCurrentSession(session) else { return }
        await refresh()
    }

    func saveSelectedContentPlan(_ data: ContentPlanFormData, userId: UUID?) async throws {
        let session = try beginMutation()
        defer { endMutation(session: session) }
        guard let selectedContentPlanItem else {
            throw AppError.notFound("Không tìm thấy Content Plan cần lưu.")
        }

        let editorChanged = (selectedContentPlanItem.editorId ?? "") != data.editorCode
        let contentChanged = selectedContentPlanItem.airDate != data.airDate ||
            selectedContentPlanItem.title != data.title.trimmingCharacters(in: .whitespacesAndNewlines) ||
            selectedContentPlanItem.note != data.note.trimmingCharacters(in: .whitespacesAndNewlines) ||
            selectedContentPlanItem.category != data.category ||
            selectedContentPlanItem.link != data.link.trimmingCharacters(in: .whitespacesAndNewlines)

        if editorChanged && contentChanged {
            throw AppError.validation("Vui lòng lưu nội dung trước, rồi phân công editor.")
        }

        let repository = try makeRepository()
        if editorChanged {
            try await repository.assignContentPlanEditor(selectedContentPlanItem, editorCode: data.editorCode)
        } else if contentChanged {
            try await repository.updateContentPlan(selectedContentPlanItem, data: data, userId: userId)
        }
        guard isCurrentSession(session) else { return }
        await refresh()
        guard isCurrentSession(session) else { return }
        self.selectedContentPlanItem = contentPlan.first { $0.id == selectedContentPlanItem.id }
    }

    func deleteSelectedContentPlan() async throws {
        let session = try beginMutation()
        defer { endMutation(session: session) }
        guard let selectedContentPlanItem else {
            throw AppError.notFound("Không tìm thấy Content Plan cần xóa.")
        }
        let repository = try makeRepository()
        try await repository.deleteContentPlan(selectedContentPlanItem)
        guard isCurrentSession(session) else { return }
        self.selectedContentPlanItem = nil
        await refresh()
    }

    private func makeRepository() throws -> OperationsRepositoryServing {
        if let repository { return repository }
        let repository = try OperationsRepository()
        self.repository = repository
        return repository
    }

    private func beginMutation() throws -> Int {
        guard !isMutating else {
            throw AppError.validation("Thao tác đang xử lý. Vui lòng đợi trong giây lát.")
        }
        isMutating = true
        errorMessage = nil
        return sessionGeneration
    }

    private func endMutation(session: Int) {
        guard isCurrentSession(session) else { return }
        isMutating = false
    }

    private func isCurrentLoad(_ generation: Int, session: Int) -> Bool {
        generation == loadGeneration && isCurrentSession(session)
    }

    private func isCurrentSession(_ session: Int) -> Bool {
        session == sessionGeneration
    }

    private func refreshLinkedTaskMutation(taskId: String) async {
        await refresh()
        selectedTask = tasks.first { $0.id == taskId }
        if let selectedTask, let contentPlanId = selectedTask.contentPlanId {
            selectedContentPlanItem = contentPlan.first { $0.id == contentPlanId }
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let configError = error as? AppConfigError {
            return configError.localizedDescription
        }

        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? "Không thể tải dữ liệu. Vui lòng thử lại." : message
    }
}
