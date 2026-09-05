import Foundation

enum TimeScopeModule: String, CaseIterable, Sendable {
    case videoTasks
    case calendar
    case contentPlan
}

protocol TimeScopePreferenceStoring: Sendable {
    func load(userID: UUID, module: TimeScopeModule) -> CHTimeScope?
    func save(_ scope: CHTimeScope, userID: UUID, module: TimeScopeModule)
}

struct UserDefaultsTimeScopePreferenceStore: TimeScopePreferenceStoring, @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(userID: UUID, module: TimeScopeModule) -> CHTimeScope? {
        CHTimeScope.fromEnvironment(defaults.string(forKey: key(userID: userID, module: module)))
    }

    func save(_ scope: CHTimeScope, userID: UUID, module: TimeScopeModule) {
        defaults.set(scope.rawValue, forKey: key(userID: userID, module: module))
    }

    private func key(userID: UUID, module: TimeScopeModule) -> String {
        "timeScope.\(userID.uuidString).\(module.rawValue)"
    }
}

enum TimeScopePreferenceStoreFactory {
    static func makeStore() -> TimeScopePreferenceStoring {
        #if DEBUG
        let suiteName = ProcessInfo.processInfo.environment["CREATIVEHUB_TIME_SCOPE_DEFAULTS_SUITE"]
        if let suiteName, !suiteName.isEmpty, let defaults = UserDefaults(suiteName: suiteName) {
            return UserDefaultsTimeScopePreferenceStore(defaults: defaults)
        }
        #endif
        return UserDefaultsTimeScopePreferenceStore()
    }
}

final class InMemoryTimeScopePreferenceStore: TimeScopePreferenceStoring, @unchecked Sendable {
    private var values: [String: CHTimeScope]
    private let lock = NSLock()

    init(values: [String: CHTimeScope] = [:]) {
        self.values = values
    }

    func load(userID: UUID, module: TimeScopeModule) -> CHTimeScope? {
        lock.lock()
        defer { lock.unlock() }
        return values[key(userID: userID, module: module)]
    }

    func save(_ scope: CHTimeScope, userID: UUID, module: TimeScopeModule) {
        lock.lock()
        values[key(userID: userID, module: module)] = scope
        lock.unlock()
    }

    private func key(userID: UUID, module: TimeScopeModule) -> String {
        "\(userID.uuidString).\(module.rawValue)"
    }
}
