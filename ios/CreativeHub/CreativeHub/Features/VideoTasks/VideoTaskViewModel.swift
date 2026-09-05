import Foundation

enum VideoTaskLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String, stale: [VideoTask])
}

@MainActor
final class VideoTaskViewModel: ObservableObject {
    @Published private(set) var loadState: VideoTaskLoadState = .idle
    @Published private(set) var tasks: [VideoTask] = []
    @Published private(set) var editors: [VideoTaskEditorOption] = []
    @Published var monthValue: String
    @Published var timeScope: CHTimeScope
    @Published var selectedDate: Date
    @Published var search = ""
    @Published var statusFilter: VideoTaskFilterStatus = .all
    @Published var editorFilter = "all"
    @Published var orderFilter = "all"
    @Published var categoryFilter = "all"
    @Published var moduleMode: VideoTaskModuleMode?
    @Published var formData: VideoTaskFormData
    @Published var acceptData = VideoTaskAcceptData(receiveDate: "", returnDate: "")
    @Published var modalError: String?
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var pendingDeleteTask: VideoTask?

    let provider: VideoTaskDataProviding
    private let nowProvider: @Sendable () -> Date
    private let preferenceStore: TimeScopePreferenceStoring
    private var currentPreferenceProfileID: UUID?

    init(
        provider: VideoTaskDataProviding = VideoTaskProviderFactory.makeProvider(),
        monthValue: String = VideoTaskProviderFactory.makeInitialMonth(),
        timeScope: CHTimeScope = VideoTaskProviderFactory.makeInitialScope(),
        selectedDate: Date = VideoTaskProviderFactory.makeInitialDate(),
        nowProvider: @escaping @Sendable () -> Date = { VideoTaskProviderFactory.makeInitialDate() },
        preferenceStore: TimeScopePreferenceStoring = TimeScopePreferenceStoreFactory.makeStore()
    ) {
        self.provider = provider
        self.monthValue = monthValue
        self.timeScope = timeScope
        self.selectedDate = selectedDate
        self.nowProvider = nowProvider
        self.preferenceStore = preferenceStore
        self.formData = .createDefault(editors: [])
    }

    var visibleTasks: [VideoTask] {
        let range = selectedRange
        return tasks
            .filter { task in
                guard let airDate = task.airDate, airDate >= range.start && airDate <= range.end else { return false }
                if statusFilter.status != nil && task.status != statusFilter.status { return false }
                if editorFilter != "all" && task.editorCode != editorFilter { return false }
                if orderFilter != "all" && task.orderTeam != orderFilter { return false }
                if categoryFilter != "all" && task.category.rawValue != categoryFilter { return false }
                if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    return [task.title, task.airDate ?? "", task.note].contains { $0.lowercased().contains(query) }
                }
                return true
            }
    }

    var hasActiveFilters: Bool {
        !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            statusFilter != .all ||
            editorFilter != "all" ||
            orderFilter != "all" ||
            categoryFilter != "all"
    }

    var selectedMonthLabel: String {
        CHTimeNavigation.monthLabel(from: monthValue)
    }

    var periodTitle: String {
        switch timeScope {
        case .day: "Video ngày"
        case .week: "Video tuần"
        case .month: "Video tháng"
        }
    }

    var weekDays: [CHTimeWeekDay] {
        CHTimeNavigation.weekDays(containing: selectedDate, today: nowProvider())
    }

    var selectedRange: CHTimeDateRange {
        CHTimeNavigation.range(for: timeScope, selectedDate: selectedDate, monthValue: monthValue)
    }

    var periodEmptyMessage: String {
        switch timeScope {
        case .day:
            "Không có video trong ngày này."
        case .week:
            "Không có video trong tuần này."
        case .month:
            "Chưa có video trong tháng này."
        }
    }

    var editorOptions: [VideoTaskEditorOption] {
        editors
    }

    func loadIfNeeded() async {
        if case .idle = loadState {
            await load()
        }
    }

    func configurePreferenceProfile(_ profileID: UUID?) async {
        guard currentPreferenceProfileID != profileID else { return }
        currentPreferenceProfileID = profileID
        let anchor = nowProvider()
        selectedDate = anchor
        monthValue = CHTimeNavigation.monthValue(from: anchor)
        if let scope = Self.debugScopeOverride() {
            timeScope = scope
        } else if let profileID, let saved = preferenceStore.load(userID: profileID, module: .videoTasks) {
            timeScope = saved
        } else {
            timeScope = .week
        }
        if case .loaded = loadState {
            await load()
        }
    }

    func load() async {
        let previousState = loadState
        loadState = .loading
        do {
            let nextTasks = try await fetchTasksForVisiblePeriod()
            async let nextEditors = provider.fetchEditorOptions()
            tasks = nextTasks
            editors = try await nextEditors
            if formData.editorCode.isEmpty {
                formData = .createDefault(editors: editors)
            }
            loadState = .loaded
        } catch {
            if AsyncCancellation.isCancellation(error) {
                loadState = previousState
                return
            }
            tasks = []
            editors = []
            loadState = .failed(Self.message(for: error), stale: [])
        }
    }

    func refresh() async -> String? {
        do {
            let nextTasks = try await fetchTasksForVisiblePeriod()
            async let nextEditors = provider.fetchEditorOptions()
            tasks = nextTasks
            editors = try await nextEditors
            if formData.editorCode.isEmpty {
                formData = .createDefault(editors: editors)
            }
            loadState = .loaded
            return nil
        } catch {
            if AsyncCancellation.isCancellation(error) {
                if !tasks.isEmpty || loadState == .loaded {
                    loadState = .loaded
                }
                return nil
            }
            if !tasks.isEmpty || loadState == .loaded {
                loadState = .loaded
            }
            return Self.message(for: error)
        }
    }

    func refreshAfterMutation() async throws {
        tasks = try await fetchTasksForVisiblePeriod()
        editors = try await provider.fetchEditorOptions()
        loadState = .loaded
    }

    func retry() async {
        await load()
    }

    func shiftMonth(_ delta: Int) async {
        timeScope = .month
        monthValue = CHTimeNavigation.shiftedMonthValue(monthValue, delta: delta)
        selectedDate = CHTimeNavigation.dateForMonthValue(monthValue)
        await load()
    }

    func shiftWeek(_ delta: Int) async {
        let shifted = CHTimeNavigation.calendar.date(byAdding: .day, value: delta * 7, to: selectedDate) ?? selectedDate
        let targetMonday = CHTimeNavigation.monday(containing: shifted)
        selectedDate = targetMonday
        monthValue = CHTimeNavigation.monthValue(from: targetMonday)
        if timeScope == .month {
            timeScope = .week
        }
        await load()
    }

    func selectDay(_ day: CHTimeWeekDay) async {
        timeScope = .day
        saveTimeScopePreference()
        selectedDate = day.date
        monthValue = CHTimeNavigation.monthValue(from: day.date)
        await load()
    }

    func selectScope(_ scope: CHTimeScope) async {
        timeScope = scope
        saveTimeScopePreference()
        if scope == .month {
            monthValue = CHTimeNavigation.monthValue(from: selectedDate)
        }
        await load()
    }

    func resetFilters() {
        search = ""
        statusFilter = .all
        editorFilter = "all"
        orderFilter = "all"
        categoryFilter = "all"
    }

    func openCreate() {
        modalError = nil
        formData = .createDefault(editors: editors)
        moduleMode = .create
    }

    func open(task: VideoTask, permissions: VideoTaskPermissions) {
        modalError = nil
        formData = .editing(task)
        if task.isLinked && task.status == .waiting && task.editorProfileID == permissions.currentProfileID {
            acceptData = VideoTaskAcceptData(
                receiveDate: VideoTaskDateFormatter.isoString(from: nowProvider()),
                returnDate: task.returnDate ?? ""
            )
        } else {
            acceptData = VideoTaskAcceptData(receiveDate: task.receiveDate ?? "", returnDate: task.returnDate ?? "")
        }
        moduleMode = VideoTaskModuleMode.resolve(task: task, permissions: permissions)
    }

    func clearModule() {
        moduleMode = nil
        pendingDeleteTask = nil
        modalError = nil
        isSaving = false
        isDeleting = false
    }

    func fieldState(permissions: VideoTaskPermissions) -> VideoTaskFieldState {
        VideoTaskFieldState.resolve(
            task: moduleMode?.task,
            permissions: permissions,
            readOnly: {
                moduleMode?.isPassiveDetail == true
            }()
        )
    }

    func save(permissions: VideoTaskPermissions) async -> Bool {
        guard let moduleMode, !isSaving else { return false }
        let fieldState = fieldState(permissions: permissions)
        guard fieldState.canUseGenericSave else { return false }
        isSaving = true
        modalError = nil
        defer { isSaving = false }

        do {
            switch moduleMode {
            case .create:
                guard permissions.canCreate else { return false }
                try await provider.createTask(formData, userID: permissions.currentProfileID)
            case .edit(let task), .linkedAdminOverride(let task):
                guard permissions.canUpdate else { return false }
                try await provider.updateTask(
                    id: task.id,
                    data: formData,
                    previousTask: task,
                    userID: permissions.currentProfileID,
                    allowLinkedOverride: permissions.isAdmin
                )
            case .linkedAccept, .linkedExecution, .linkedPassiveDetail, .readOnly:
                return false
            }
            try await refreshAfterMutation()
            return true
        } catch {
            if AsyncCancellation.isCancellation(error) {
                return false
            }
            modalError = Self.message(for: error)
            return false
        }
    }

    func accept(permissions: VideoTaskPermissions) async -> Bool {
        guard let task = moduleMode?.task, fieldState(permissions: permissions).canAccept, !isSaving else { return false }
        isSaving = true
        modalError = nil
        defer { isSaving = false }
        do {
            try await provider.acceptLinkedTask(id: task.id, data: acceptData)
            try await refreshAfterMutation()
            return true
        } catch {
            if AsyncCancellation.isCancellation(error) {
                return false
            }
            modalError = Self.message(for: error)
            return false
        }
    }

    func saveExecution(permissions: VideoTaskPermissions) async -> Bool {
        guard let task = moduleMode?.task, fieldState(permissions: permissions).canSaveExecution, !isSaving else { return false }
        isSaving = true
        modalError = nil
        defer { isSaving = false }
        do {
            try await provider.updateLinkedExecution(id: task.id, data: executionData)
            try await refreshAfterMutation()
            return true
        } catch {
            if AsyncCancellation.isCancellation(error) {
                return false
            }
            modalError = Self.message(for: error)
            return false
        }
    }

    func complete(permissions: VideoTaskPermissions) async -> Bool {
        guard let task = moduleMode?.task, fieldState(permissions: permissions).canComplete, !isSaving else { return false }
        isSaving = true
        modalError = nil
        defer { isSaving = false }
        do {
            try await provider.updateLinkedExecution(id: task.id, data: executionData)
            try await provider.completeLinkedTask(id: task.id, resultLink: formData.resultLink)
            try await refreshAfterMutation()
            return true
        } catch {
            if AsyncCancellation.isCancellation(error) {
                return false
            }
            modalError = Self.message(for: error)
            return false
        }
    }

    func requestDelete() {
        guard let task = moduleMode?.task else { return }
        pendingDeleteTask = task
    }

    func cancelDelete() {
        pendingDeleteTask = nil
    }

    func confirmDelete(permissions: VideoTaskPermissions) async -> Bool {
        guard let task = pendingDeleteTask, permissions.canDelete, !isDeleting else { return false }
        isDeleting = true
        modalError = nil
        defer {
            isDeleting = false
            pendingDeleteTask = nil
        }
        do {
            try await provider.deleteTask(task, userID: permissions.currentProfileID)
            try await refreshAfterMutation()
            return true
        } catch {
            if AsyncCancellation.isCancellation(error) {
                return false
            }
            modalError = Self.message(for: error)
            return false
        }
    }

    private var executionData: VideoTaskExecutionData {
        VideoTaskExecutionData(
            orderTeam: formData.orderTeam,
            priority: formData.priority,
            resize: formData.resize,
            receiveDate: formData.receiveDate,
            returnDate: formData.returnDate,
            resultLink: formData.resultLink
        )
    }

    private func fetchTasksForVisiblePeriod() async throws -> [VideoTask] {
        var merged: [VideoTask] = []
        var seenIDs = Set<UUID>()
        for value in CHTimeNavigation.monthValuesTouching(range: selectedRange) {
            let page = try await provider.fetchTasks(monthValue: value)
            for task in page where !seenIDs.contains(task.id) {
                seenIDs.insert(task.id)
                merged.append(task)
            }
        }
        return merged.sorted {
            let air = ($0.airDate ?? "9999-12-31").localizedCompare($1.airDate ?? "9999-12-31")
            if air != .orderedSame { return air == .orderedAscending }
            return $0.sequence < $1.sequence
        }
        .enumerated()
        .map { index, task in
            var copy = task
            copy.sequence = index + 1
            return copy
        }
    }

    private func saveTimeScopePreference() {
        guard let currentPreferenceProfileID else { return }
        preferenceStore.save(timeScope, userID: currentPreferenceProfileID, module: .videoTasks)
    }

    static func message(for error: Error) -> String {
        if AsyncCancellation.isCancellation(error) {
            return "Không thể xử lý Video Task. Vui lòng thử lại."
        }
        if let localized = error as? LocalizedError, let message = localized.errorDescription, !message.isEmpty {
            return message
        }
        return error.localizedDescription.isEmpty
            ? "Không thể xử lý Video Task. Vui lòng thử lại."
            : error.localizedDescription
    }

    private static func debugScopeOverride() -> CHTimeScope? {
        #if DEBUG
        return CHTimeScope.fromEnvironment(ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE11_SCOPE"])
        #else
        return nil
        #endif
    }
}

enum VideoTaskProviderFactory {
    static func makeProvider() -> VideoTaskDataProviding {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE6_VIDEO_TASKS_FIXTURE"] {
        case "full":
            return VideoTaskFixtureProvider(mode: .full)
        case "empty":
            return VideoTaskFixtureProvider(mode: .empty)
        case "error":
            return VideoTaskFixtureProvider(mode: .error)
        default:
            break
        }
        #endif
        return VideoTaskSupabaseRepository()
    }

    static func makeInitialMonth() -> String {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE6_MONTH"], !value.isEmpty {
            return value
        }
        if ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE6_VIDEO_TASKS_FIXTURE"] != nil {
            return "2026-08"
        }
        #endif
        return VideoTaskDateFormatter.monthValue(from: Date())
    }

    static func makeInitialScope() -> CHTimeScope {
        #if DEBUG
        if let scope = CHTimeScope.fromEnvironment(ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE11_SCOPE"]) {
            return scope
        }
        #endif
        return .week
    }

    static func makeInitialDate() -> Date {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE11_DATE"],
           let date = CHTimeNavigation.date(from: value) {
            return date
        }
        if ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE6_VIDEO_TASKS_FIXTURE"] != nil,
           let date = CHTimeNavigation.date(from: "2026-08-17") {
            return date
        }
        #endif
        return Date()
    }
}
