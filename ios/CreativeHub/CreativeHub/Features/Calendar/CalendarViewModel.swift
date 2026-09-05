import Foundation

enum CalendarLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String, stale: [CalendarShoot])
}

enum CalendarModuleMode: Equatable {
    case create
    case edit(CalendarShoot)
    case readOnly(CalendarShoot)

    var title: String {
        switch self {
        case .create: "Thêm lịch quay"
        case .edit: "Chỉnh sửa lịch quay"
        case .readOnly: "Chi tiết lịch quay"
        }
    }

    var shootID: UUID? {
        switch self {
        case .create: nil
        case .edit(let shoot), .readOnly(let shoot): shoot.id
        }
    }

    var isEditable: Bool {
        switch self {
        case .create, .edit: true
        case .readOnly: false
        }
    }
}

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published private(set) var loadState: CalendarLoadState = .idle
    @Published private(set) var shoots: [CalendarShoot] = []
    @Published private(set) var editorOptions: [CalendarEditorOption] = []
    @Published var selectedDate: Date
    @Published var timeScope: CHTimeScope
    @Published var monthValue: String
    @Published var filter: CalendarShootFilter = .all
    @Published var moduleMode: CalendarModuleMode?
    @Published var formData: CalendarFormData
    @Published var modalError: String?
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var pendingDeleteShoot: CalendarShoot?

    let provider: CalendarDataProviding
    private let nowProvider: @Sendable () -> Date
    private let preferenceStore: TimeScopePreferenceStoring
    private var currentPreferenceProfileID: UUID?

    init(
        provider: CalendarDataProviding = CalendarProviderFactory.makeProvider(),
        initialDate: Date = CalendarProviderFactory.makeInitialDate(),
        timeScope: CHTimeScope = CalendarProviderFactory.makeInitialScope(),
        nowProvider: @escaping @Sendable () -> Date = { CalendarProviderFactory.makeInitialDate() },
        preferenceStore: TimeScopePreferenceStoring = TimeScopePreferenceStoreFactory.makeStore()
    ) {
        self.provider = provider
        self.selectedDate = initialDate
        self.timeScope = timeScope
        self.monthValue = CHTimeNavigation.monthValue(from: initialDate)
        self.formData = .createDefault(date: initialDate)
        self.nowProvider = nowProvider
        self.preferenceStore = preferenceStore
    }

    var weekDays: [CHTimeWeekDay] {
        CHTimeNavigation.weekDays(containing: selectedDate, today: nowProvider())
    }

    var visibleShoots: [CalendarShoot] {
        let range = selectedRange
        return shoots
            .filter {
                let iso = CalendarDateFormatter.isoString(from: $0.date)
                return iso >= range.start && iso <= range.end
            }
            .filter { filter.type == nil || $0.type == filter.type }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date { return lhs.id.uuidString < rhs.id.uuidString }
                return lhs.date < rhs.date
            }
    }

    var monthHasShoots: Bool {
        let range = selectedRange
        return shoots.contains {
            let iso = CalendarDateFormatter.isoString(from: $0.date)
            return iso >= range.start && iso <= range.end
        }
    }

    var selectedMonthLabel: String {
        CHTimeNavigation.monthLabel(from: monthValue)
    }

    var periodTitle: String {
        switch timeScope {
        case .day: "Lịch ngày"
        case .week: "Lịch tuần"
        case .month: "Lịch tháng"
        }
    }

    var selectedRange: CHTimeDateRange {
        CHTimeNavigation.range(for: timeScope, selectedDate: selectedDate, monthValue: monthValue)
    }

    var periodEmptyMessage: String {
        switch timeScope {
        case .day: "Không có lịch quay trong ngày này."
        case .week: "Không có lịch quay trong tuần này."
        case .month: "Không có lịch quay trong tháng này."
        }
    }

    func configurePreferenceProfile(_ profileID: UUID?) async {
        guard currentPreferenceProfileID != profileID else { return }
        currentPreferenceProfileID = profileID
        let anchor = nowProvider()
        selectedDate = anchor
        monthValue = CHTimeNavigation.monthValue(from: anchor)
        formData = .createDefault(date: anchor)
        if let scope = Self.debugScopeOverride() {
            timeScope = scope
        } else if let profileID, let saved = preferenceStore.load(userID: profileID, module: .calendar) {
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
        let range = selectedRange
        do {
            async let nextShoots = provider.fetchShoots(startDate: range.start, endDate: range.end)
            async let nextEditors = provider.fetchEditorOptions()
            shoots = try await nextShoots
            editorOptions = try await nextEditors
            loadState = .loaded
        } catch {
            if AsyncCancellation.isCancellation(error) {
                loadState = previousState
                return
            }
            shoots = []
            editorOptions = []
            loadState = .failed(Self.message(for: error), stale: [])
        }
    }

    func refresh() async -> String? {
        let range = selectedRange
        do {
            async let nextShoots = provider.fetchShoots(startDate: range.start, endDate: range.end)
            async let nextEditors = provider.fetchEditorOptions()
            shoots = try await nextShoots
            editorOptions = try await nextEditors
            loadState = .loaded
            return nil
        } catch {
            if AsyncCancellation.isCancellation(error) {
                if !shoots.isEmpty || loadState == .loaded {
                    loadState = .loaded
                }
                return nil
            }
            if !shoots.isEmpty || loadState == .loaded {
                loadState = .loaded
            }
            return Self.message(for: error)
        }
    }

    func retry() async {
        await load()
    }

    func refreshAfterMutation() async throws {
        let range = selectedRange
        shoots = try await provider.fetchShoots(startDate: range.start, endDate: range.end)
        editorOptions = try await provider.fetchEditorOptions()
        loadState = .loaded
    }

    func selectDay(_ day: CHTimeWeekDay) async {
        timeScope = .day
        saveTimeScopePreference()
        selectedDate = day.date
        monthValue = CHTimeNavigation.monthValue(from: day.date)
        if case .create = moduleMode {
            formData.date = day.isoDate
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

    func shiftMonth(_ delta: Int) async {
        timeScope = .month
        monthValue = CHTimeNavigation.shiftedMonthValue(monthValue, delta: delta)
        selectedDate = CHTimeNavigation.dateForMonthValue(monthValue)
        await load()
    }

    func openCreate() {
        modalError = nil
        formData = .createDefault(date: selectedDate)
        moduleMode = .create
    }

    func open(shoot: CalendarShoot, canUpdate: Bool) {
        modalError = nil
        formData = .editing(shoot)
        moduleMode = canUpdate ? .edit(shoot) : .readOnly(shoot)
    }

    func clearModule() {
        moduleMode = nil
        pendingDeleteShoot = nil
        modalError = nil
        isSaving = false
        isDeleting = false
    }

    func save() async -> Bool {
        guard let moduleMode, moduleMode.isEditable, !isSaving else {
            return false
        }
        isSaving = true
        modalError = nil
        defer { isSaving = false }

        do {
            switch moduleMode {
            case .create:
                try await provider.createShoot(formData)
            case .edit(let shoot):
                try await provider.updateShoot(id: shoot.id, data: formData)
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
            return false
        }
    }

    func requestDelete() {
        guard case .edit(let shoot) = moduleMode else {
            return
        }
        pendingDeleteShoot = shoot
    }

    func cancelDelete() {
        pendingDeleteShoot = nil
    }

    func confirmDelete() async -> Bool {
        guard let shoot = pendingDeleteShoot, !isDeleting else {
            return false
        }
        isDeleting = true
        modalError = nil
        defer {
            isDeleting = false
            pendingDeleteShoot = nil
        }
        do {
            try await provider.deleteShoot(id: shoot.id)
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

    private func saveTimeScopePreference() {
        guard let currentPreferenceProfileID else { return }
        preferenceStore.save(timeScope, userID: currentPreferenceProfileID, module: .calendar)
    }

    static func message(for error: Error) -> String {
        if AsyncCancellation.isCancellation(error) {
            return "Không thể xử lý lịch quay. Vui lòng thử lại."
        }
        if let localized = error as? LocalizedError, let message = localized.errorDescription, !message.isEmpty {
            return message
        }
        return error.localizedDescription.isEmpty
            ? "Không thể xử lý lịch quay. Vui lòng thử lại."
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

enum CalendarProviderFactory {
    static func makeProvider() -> CalendarDataProviding {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE5_CALENDAR_FIXTURE"] {
        case "full":
            return CalendarFixtureProvider(mode: .full)
        case "empty":
            return CalendarFixtureProvider(mode: .empty)
        case "error":
            return CalendarFixtureProvider(mode: .error)
        case "readonly":
            return CalendarFixtureProvider(mode: .readonly)
        case "filter-empty":
            return CalendarFixtureProvider(mode: .filterEmpty)
        default:
            break
        }
        #endif
        return CalendarSupabaseRepository()
    }

    static func makeInitialDate() -> Date {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE5_DATE"],
           let date = CalendarDateFormatter.date(from: value) {
            return date
        }
        if ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE5_CALENDAR_FIXTURE"] != nil,
           let date = CalendarDateFormatter.date(from: "2026-08-17") {
            return date
        }
        #endif
        return Date()
    }

    static func makeInitialScope() -> CHTimeScope {
        #if DEBUG
        if let scope = CHTimeScope.fromEnvironment(ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE11_SCOPE"]) {
            return scope
        }
        #endif
        return .week
    }
}
