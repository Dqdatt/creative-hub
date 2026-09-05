import Foundation

@MainActor
final class InAppNotificationRefreshLoop: ObservableObject {
    @Published private(set) var tick = UUID()
    private(set) var isRunning = false

    private let intervalNanoseconds: UInt64
    private var task: Task<Void, Never>?
    private var generation = UUID()

    init(intervalNanoseconds: UInt64 = 60_000_000_000) {
        self.intervalNanoseconds = intervalNanoseconds
    }

    func reconcile(isAuthenticated: Bool, isSceneActive: Bool) {
        guard isAuthenticated, isSceneActive else {
            stop()
            return
        }
        start()
    }

    func stop() {
        generation = UUID()
        task?.cancel()
        task = nil
        isRunning = false
    }

    private func start() {
        guard task == nil else { return }

        let currentGeneration = UUID()
        let intervalNanoseconds = intervalNanoseconds
        generation = currentGeneration
        isRunning = true
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: intervalNanoseconds)
                } catch {
                    break
                }
                guard !Task.isCancelled else { break }
                guard let self else { return }
                guard self.generation == currentGeneration else { return }
                self.tick = UUID()
            }

            guard let self else { return }
            if self.generation == currentGeneration {
                self.task = nil
                self.isRunning = false
            }
        }
    }

    deinit {
        task?.cancel()
    }
}
