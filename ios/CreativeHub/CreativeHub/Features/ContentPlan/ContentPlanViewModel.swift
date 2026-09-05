import Foundation

enum ContentPlanLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String, stale: [ContentPlanItem])
}

@MainActor
final class ContentPlanViewModel: ObservableObject {
    @Published private(set) var loadState: ContentPlanLoadState = .idle
    @Published private(set) var items: [ContentPlanItem] = []
    @Published private(set) var editors: [ContentPlanEditorOption] = []
    @Published var monthValue: String
    @Published var timeScope: CHTimeScope
    @Published var selectedDate: Date
    @Published var search = ""
    @Published var editorFilter = "all"
    @Published var categoryFilter: ContentPlanFilterCategory = .all
    @Published var moduleMode: ContentPlanModuleMode?
    @Published var formData: ContentPlanFormData
    @Published var modalError: String?
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var pendingDeleteItem: ContentPlanItem?

    let provider: ContentPlanDataProviding
    private let nowProvider: @Sendable () -> Date
    private let preferenceStore: TimeScopePreferenceStoring
    private var currentPreferenceProfileID: UUID?

    init(
        provider: ContentPlanDataProviding = ContentPlanDataProviderFactory.makeProvider(),
        monthValue: String = ContentPlanDataProviderFactory.makeInitialMonth(),
        timeScope: CHTimeScope = ContentPlanDataProviderFactory.makeInitialScope(),
        selectedDate: Date = ContentPlanDataProviderFactory.makeInitialDate(),
        nowProvider: @escaping @Sendable () -> Date = { ContentPlanDataProviderFactory.makeInitialDate() },
        preferenceStore: TimeScopePreferenceStoring = TimeScopePreferenceStoreFactory.makeStore()
    ) {
        self.provider = provider
        self.monthValue = monthValue
        self.timeScope = timeScope
        self.selectedDate = selectedDate
        self.nowProvider = nowProvider
        self.preferenceStore = preferenceStore
        self.formData = .createDefault(monthValue: monthValue)
    }

    var visibleItems: [ContentPlanItem] {
        let range = selectedRange
        return items
            .filter { item in
                guard item.airDate >= range.start && item.airDate <= range.end else { return false }
                if editorFilter != "all" && item.editorCode != editorFilter { return false }
                if let category = categoryFilter.category, item.category != category { return false }
                let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !query.isEmpty {
                    return item.title.lowercased().contains(query)
                }
                return true
            }
            .sorted(by: ContentPlanSorter.areInIncreasingOrder)
    }

    var hasActiveFilters: Bool {
        !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            editorFilter != "all" ||
            categoryFilter != .all
    }

    var selectedMonthLabel: String {
        CHTimeNavigation.monthLabel(from: monthValue)
    }

    var periodTitle: String {
        switch timeScope {
        case .day: "Content ngày"
        case .week: "Content tuần"
        case .month: "Content tháng"
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
        case .day: "Không có Content Plan trong ngày này."
        case .week: "Không có Content Plan trong tuần này."
        case .month: "Không có Content Plan trong tháng này."
        }
    }

    var editorOptions: [ContentPlanEditorOption] { editors }

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
        if case .create = moduleMode {
            formData = .createDefault(monthValue: monthValue)
        }
        if let scope = Self.debugScopeOverride() {
            timeScope = scope
        } else if let profileID, let saved = preferenceStore.load(userID: profileID, module: .contentPlan) {
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
            let nextItems = try await fetchItemsForVisiblePeriod()
            async let nextEditors = provider.fetchEditorOptions()
            items = nextItems
            editors = try await nextEditors
            loadState = .loaded
        } catch {
            if AsyncCancellation.isCancellation(error) {
                loadState = previousState
                return
            }
            items = []
            editors = []
            loadState = .failed(Self.loadMessage(for: error), stale: [])
        }
    }

    func refresh() async -> String? {
        do {
            let nextItems = try await fetchItemsForVisiblePeriod()
            async let nextEditors = provider.fetchEditorOptions()
            items = nextItems
            editors = try await nextEditors
            loadState = .loaded
            return nil
        } catch {
            if AsyncCancellation.isCancellation(error) {
                if !items.isEmpty || loadState == .loaded {
                    loadState = .loaded
                }
                return nil
            }
            if !items.isEmpty || loadState == .loaded {
                loadState = .loaded
            }
            return Self.loadMessage(for: error)
        }
    }

    func refreshAfterMutation() async throws {
        items = try await fetchItemsForVisiblePeriod()
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
        if case .create = moduleMode {
            formData.airDate = day.isoDate
        }
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
        editorFilter = "all"
        categoryFilter = .all
    }

    func openCreate() {
        modalError = nil
        pendingDeleteItem = nil
        formData = .createDefault(monthValue: monthValue)
        moduleMode = .create
    }

    func open(item: ContentPlanItem, permissions: ContentPlanPermissions) {
        modalError = nil
        pendingDeleteItem = nil
        formData = .editing(item)
        moduleMode = ContentPlanModuleMode.resolve(item: item, permissions: permissions)
    }

    func clearModule() {
        moduleMode = nil
        pendingDeleteItem = nil
        modalError = nil
        isSaving = false
        isDeleting = false
    }

    func fieldState(permissions: ContentPlanPermissions) -> ContentPlanFieldState {
        ContentPlanFieldState.resolve(mode: moduleMode, permissions: permissions)
    }

    func save(permissions: ContentPlanPermissions) async -> Bool {
        guard let mode = moduleMode, !isSaving else { return false }
        let fieldState = fieldState(permissions: permissions)
        guard fieldState.canSave else { return false }
        isSaving = true
        modalError = nil
        defer { isSaving = false }

        do {
            switch mode {
            case .create:
                guard permissions.canCreate else { return false }
                try await provider.createItem(formData, userID: permissions.currentProfileID)
            case .edit(let item), .assign(let item):
                let nextData = nextFormData(from: item, fieldState: fieldState)
                let editorChanged = item.editorCode != nextData.editorCode
                let contentChanged = hasContentFieldChanges(item: item, data: nextData)
                if editorChanged && contentChanged {
                    throw ContentPlanValidationError.mixedContentAndAssignment
                }
                if editorChanged {
                    if nextData.editorCode.isEmpty { throw ContentPlanValidationError.missingEditor }
                    _ = try await provider.assignEditor(id: item.id, editorCode: nextData.editorCode)
                } else if contentChanged {
                    try await provider.updateItem(id: item.id, data: nextData, previousItem: item, userID: permissions.currentProfileID)
                } else {
                    return true
                }
            case .readOnly:
                return false
            }
            try await refreshAfterMutation()
            return true
        } catch {
            if AsyncCancellation.isCancellation(error) {
                return false
            }
            modalError = Self.message(for: error)
            if case .edit = mode {
                try? await refreshAfterMutation()
            }
            if case .assign = mode {
                try? await refreshAfterMutation()
            }
            return false
        }
    }

    func requestDelete() {
        guard let item = moduleMode?.item else { return }
        pendingDeleteItem = item
    }

    func cancelDelete() {
        pendingDeleteItem = nil
    }

    func confirmDelete(permissions: ContentPlanPermissions) async -> Bool {
        guard let item = pendingDeleteItem, permissions.canDelete, !isDeleting else { return false }
        isDeleting = true
        modalError = nil
        defer {
            isDeleting = false
            pendingDeleteItem = nil
        }
        do {
            try await provider.deleteItem(id: item.id)
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

    private func nextFormData(from item: ContentPlanItem, fieldState: ContentPlanFieldState) -> ContentPlanFormData {
        ContentPlanFormData(
            airDate: fieldState.canEditAirDate ? formData.airDate : item.airDate,
            title: fieldState.canEditTitle ? formData.title.trimmingCharacters(in: .whitespacesAndNewlines) : item.title,
            note: fieldState.canEditNote ? formData.note.trimmingCharacters(in: .whitespacesAndNewlines) : item.note,
            category: fieldState.canEditCategory ? formData.category : item.category,
            editorCode: fieldState.canEditEditor ? formData.editorCode : item.editorCode,
            link: fieldState.canEditLink ? formData.link.trimmingCharacters(in: .whitespacesAndNewlines) : item.link
        )
    }

    private func hasContentFieldChanges(item: ContentPlanItem, data: ContentPlanFormData) -> Bool {
        item.airDate != data.airDate ||
            item.title != data.title ||
            item.note != data.note ||
            item.category != data.category ||
            item.link != data.link
    }

    private func fetchItemsForVisiblePeriod() async throws -> [ContentPlanItem] {
        var merged: [ContentPlanItem] = []
        var seenIDs = Set<UUID>()
        for value in CHTimeNavigation.monthValuesTouching(range: selectedRange) {
            let page = try await provider.fetchItems(monthValue: value)
            for item in page where !seenIDs.contains(item.id) {
                seenIDs.insert(item.id)
                merged.append(item)
            }
        }
        return merged.sorted(by: ContentPlanSorter.areInIncreasingOrder)
    }

    private func saveTimeScopePreference() {
        guard let currentPreferenceProfileID else { return }
        preferenceStore.save(timeScope, userID: currentPreferenceProfileID, module: .contentPlan)
    }

    static func message(for error: Error) -> String {
        if AsyncCancellation.isCancellation(error) {
            return "Không thể xử lý Content Plan. Vui lòng thử lại."
        }
        if let localized = error as? LocalizedError, let message = localized.errorDescription, !message.isEmpty {
            return message
        }
        return error.localizedDescription.isEmpty
            ? "Không thể xử lý Content Plan. Vui lòng thử lại."
            : error.localizedDescription
    }

    static func loadMessage(for error: Error) -> String {
        let message = Self.message(for: error)
        let unsafeMarkers = ["fixture", "backend", "rpc", "sql", "supabase", "postgrest"]
        if unsafeMarkers.contains(where: { message.localizedCaseInsensitiveContains($0) }) {
            return "Không thể tải dữ liệu Content Plan. Vui lòng thử lại."
        }
        return message.isEmpty ? "Không thể tải dữ liệu Content Plan. Vui lòng thử lại." : message
    }

    private static func debugScopeOverride() -> CHTimeScope? {
        #if DEBUG
        return CHTimeScope.fromEnvironment(ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE11_SCOPE"])
        #else
        return nil
        #endif
    }
}

enum ContentPlanDataProviderFactory {
    static func makeProvider() -> ContentPlanDataProviding {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE7_CONTENT_PLAN_FIXTURE"] {
        case "full":
            return ContentPlanFixtureProvider(mode: .full)
        case "empty":
            return ContentPlanFixtureProvider(mode: .empty)
        case "error":
            return ContentPlanFixtureProvider(mode: .error)
        default:
            break
        }
        #endif
        return ContentPlanSupabaseRepository()
    }

    static func makeInitialMonth() -> String {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE7_MONTH"], !value.isEmpty {
            return value
        }
        if ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE7_CONTENT_PLAN_FIXTURE"] != nil {
            return "2026-08"
        }
        #endif
        return ContentPlanDateFormatter.monthValue(from: Date())
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
        if ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE7_CONTENT_PLAN_FIXTURE"] != nil,
           let date = CHTimeNavigation.date(from: "2026-08-17") {
            return date
        }
        #endif
        return Date()
    }
}
