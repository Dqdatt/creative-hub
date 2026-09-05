import Foundation

@MainActor
final class OverviewViewModel: ObservableObject {
    @Published private(set) var state: OverviewLoadState = .idle
    @Published private(set) var isRefreshing = false

    let provider: OverviewDataProviding
    let month: OverviewMonth

    private var hasLoaded = false
    private var requestID = 0

    init(
        provider: OverviewDataProviding = OverviewProviderFactory.makeProvider(),
        month: OverviewMonth = OverviewProviderFactory.makeMonth()
    ) {
        self.provider = provider
        self.month = month
    }

    var usesProductionData: Bool {
        provider.usesProductionData
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func retry() async {
        await load()
    }

    func refresh() async -> String? {
        await load(isRefresh: true)
    }

    @discardableResult
    private func load(isRefresh: Bool = false) async -> String? {
        requestID += 1
        let currentRequest = requestID
        let previousState = state
        let staleDashboard = state.dashboard

        if isRefresh {
            isRefreshing = true
        } else {
            state = .loading
        }

        do {
            let rawData = try await provider.fetchOverviewRawData(month: month)
            guard currentRequest == requestID else { return nil }
            let dashboard = OverviewAggregator.aggregate(rawData: rawData, month: month)
            hasLoaded = true
            state = .loaded(dashboard)
            isRefreshing = false
            return nil
        } catch {
            guard currentRequest == requestID else { return nil }
            if AsyncCancellation.isCancellation(error) {
                state = previousState
                isRefreshing = false
                return nil
            }
            hasLoaded = true
            let message = Self.errorMessage(for: error)
            state = .failed(message, stale: staleDashboard)
            isRefreshing = false
            return message
        }
    }

    private static func errorMessage(for error: Error) -> String {
        if AsyncCancellation.isCancellation(error) {
            return "Không thể tải dữ liệu tổng quan. Vui lòng thử lại."
        }
        if let overviewError = error as? OverviewRepositoryError, overviewError == .configurationMissing {
            return "Kết nối dữ liệu chưa sẵn sàng. Vui lòng liên hệ quản trị viên."
        }
        return error.localizedDescription.isEmpty
            ? "Không thể tải dữ liệu tổng quan. Vui lòng thử lại."
            : error.localizedDescription
    }
}

extension OverviewLoadState {
    var dashboard: OverviewDashboard? {
        switch self {
        case .loaded(let dashboard):
            dashboard
        case .failed(_, let stale):
            stale
        case .idle, .loading:
            nil
        }
    }
}

enum OverviewProviderFactory {
    static func makeMonth() -> OverviewMonth {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE4_MONTH"] {
            let parts = value.split(separator: "-").compactMap { Int($0) }
            if parts.count == 2 {
                return OverviewMonth(year: parts[0], month: parts[1])
            }
        }
        #endif
        return OverviewMonth()
    }

    static func makeProvider() -> OverviewDataProviding {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE4_OVERVIEW_FIXTURE"] {
        case "visual":
            return OverviewFixtureProvider(fixture: .visual)
        case "zero":
            return OverviewFixtureProvider(fixture: .zero)
        case "error":
            return OverviewFixtureProvider(fixture: .error)
        default:
            break
        }
        #endif
        return OverviewSupabaseRepository()
    }
}
