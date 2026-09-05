import SwiftUI

struct OverviewView: View {
    @StateObject private var viewModel: OverviewViewModel

    init(viewModel: OverviewViewModel = OverviewViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                CHStateView(
                    kind: .loading,
                    title: "Đang tải tổng quan",
                    message: "Dữ liệu tháng đang được đồng bộ."
                )
                .frame(minHeight: 520)
                .accessibilityIdentifier("overview.loading")
            case .failed(let message, let stale):
                if let stale {
                    dashboard(stale)
                        .overlay(alignment: .top) {
                            OverviewInlineError(message: message) {
                                Task { await viewModel.retry() }
                            }
                        }
                } else {
                    CHStateView(
                        kind: .error,
                        title: "Không thể tải tổng quan",
                        message: message,
                        actionTitle: "Thử lại"
                    ) {
                        Task { await viewModel.retry() }
                    }
                    .frame(minHeight: 520)
                    .accessibilityIdentifier("overview.load-error")
                }
            case .loaded(let dashboard):
                self.dashboard(dashboard)
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private func dashboard(_ dashboard: OverviewDashboard) -> some View {
        VStack(spacing: 10) {
            OverviewHeroCard(dashboard: dashboard)
                .accessibilityIdentifier("overview.hero")

            OverviewCompactMetrics(dashboard: dashboard)
                .accessibilityIdentifier("overview.metrics")

            OverviewTeamOrderCard(orders: dashboard.teamOrders)
                .accessibilityIdentifier("overview.team-order")

            OverviewEditorWorkloadCard(workloads: dashboard.editorWorkload)
                .accessibilityIdentifier("overview.editor-workload")

            OverviewBottomMetricsCard(dashboard: dashboard)
                .accessibilityIdentifier("overview.bottom-metrics")
        }
        .padding(.top, 10)
        .accessibilityIdentifier(dashboard.isZeroData ? "overview.dashboard.zero" : "overview.dashboard")
    }
}

private struct OverviewHeroCard: View {
    var dashboard: OverviewDashboard

    var body: some View {
        OverviewCard {
            VStack(spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dashboard.month.displayTitle)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(CHColors.muted)
                            .textCase(.uppercase)
                        Text("\(dashboard.totalVideos)")
                            .font(.system(size: 34, weight: .heavy))
                            .foregroundStyle(CHColors.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("Video trong tháng")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(CHColors.muted)
                    }

                    Spacer(minLength: 8)

                    OverviewRing(percent: dashboard.completionPercent, ratio: dashboard.completionRatio)
                        .accessibilityIdentifier("overview.completion-ring")
                }

                OverviewProgressChart(points: dashboard.chartPoints, month: dashboard.month)
                    .frame(height: 132)
                    .accessibilityIdentifier("overview.chart")
            }
            .padding(14)
        }
        .accessibilityLabel("\(dashboard.month.displayTitle), \(dashboard.totalVideos) video trong tháng, hoàn thành \(dashboard.completionPercent)%")
    }
}

private struct OverviewRing: View {
    var percent: Int
    var ratio: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: 0xE9EDF6), lineWidth: 9)
            Circle()
                .trim(from: 0, to: max(0, min(1, ratio)))
                .stroke(
                    CHColors.primaryGradient,
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(Color.white)
                .padding(9)
            VStack(spacing: 0) {
                Text("\(percent)%")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(CHColors.ink)
                Text("DONE")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(CHColors.muted)
            }
        }
        .frame(width: 66, height: 66)
        .accessibilityLabel("Hoàn thành \(percent)%")
    }
}

private struct OverviewProgressChart: View {
    var points: [OverviewChartPoint]
    var month: OverviewMonth

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                let size = proxy.size
                let chartPath = path(in: size, closeArea: false)
                let areaPath = path(in: size, closeArea: true)

                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [CHColors.purple.opacity(0.07), CHColors.purple.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    areaPath
                        .fill(
                            LinearGradient(
                                colors: [CHColors.purple.opacity(0.24), CHColors.purple.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    chartPath
                        .stroke(CHColors.primaryGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    ForEach(pointsForMarkers()) { point in
                        Circle()
                            .fill(Color.white)
                            .overlay(Circle().stroke(CHColors.purple, lineWidth: 2.5))
                            .frame(width: 8, height: 8)
                            .position(position(for: point, in: size))
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            .frame(height: 116)

            HStack {
                ForEach(month.axisLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x9AA4B7))
                    if label != month.axisLabels.last {
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 2)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(CHColors.purple.opacity(0.035))
        )
        .accessibilityLabel("Biểu đồ tiến độ hoàn thành trong tháng, \(points.last?.value ?? 0) video đã hoàn thành")
    }

    private func path(in size: CGSize, closeArea: Bool) -> Path {
        let normalized = points.isEmpty ? [OverviewChartPoint(day: 1, value: 0), OverviewChartPoint(day: month.daysInMonth, value: 0)] : points
        var path = Path()
        let positions = normalized.map { position(for: $0, in: size) }
        guard let first = positions.first else { return path }
        path.move(to: first)
        positions.dropFirst().forEach { path.addLine(to: $0) }
        if closeArea, let last = positions.last {
            path.addLine(to: CGPoint(x: last.x, y: size.height - 12))
            path.addLine(to: CGPoint(x: first.x, y: size.height - 12))
            path.closeSubpath()
        }
        return path
    }

    private func position(for point: OverviewChartPoint, in size: CGSize) -> CGPoint {
        let maxValue = max(points.map(\.value).max() ?? 0, 1)
        let x = CGFloat(point.day - 1) / CGFloat(max(1, month.daysInMonth - 1)) * max(1, size.width - 12) + 6
        let progress = CGFloat(point.value) / CGFloat(maxValue)
        let y = (size.height - 18) - progress * (size.height - 34) + 6
        return CGPoint(x: x, y: y)
    }

    private func pointsForMarkers() -> [OverviewChartPoint] {
        guard !points.isEmpty else { return [] }
        let days = [8, 15, 22, month.daysInMonth]
        return days.compactMap { target in
            points.last { $0.day <= target }
        }
    }
}

private struct OverviewCompactMetrics: View {
    var dashboard: OverviewDashboard

    var body: some View {
        HStack(spacing: 8) {
            OverviewMetricCard(label: "Hoàn thành", value: dashboard.completedVideos, color: CHColors.green)
                .accessibilityIdentifier("overview.metric.completed")
            OverviewMetricCard(label: "Lịch quay", value: dashboard.shootCount, color: CHColors.purple)
                .accessibilityIdentifier("overview.metric.shoots")
            OverviewMetricCard(label: "Còn lại", value: dashboard.remainingVideos, color: CHColors.blue)
                .accessibilityIdentifier("overview.metric.remaining")
        }
    }
}

private struct OverviewMetricCard: View {
    var label: String
    var value: Int
    var color: Color

    var body: some View {
        OverviewCard {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(label)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(CHColors.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                Text("\(value)")
                    .font(.system(size: 21, weight: .heavy))
                    .foregroundStyle(CHColors.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 11)
        }
        .accessibilityLabel("\(label): \(value)")
    }
}

private struct OverviewTeamOrderCard: View {
    var orders: [OverviewTeamOrder]

    private var total: Int {
        orders.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        OverviewCard {
            VStack(alignment: .leading, spacing: 10) {
                OverviewPanelTitle("Team Order")

                GeometryReader { proxy in
                    HStack(spacing: 0) {
                        if total == 0 {
                            Capsule()
                                .fill(Color(hex: 0xEDF0F5))
                                .frame(width: proxy.size.width)
                        } else {
                            ForEach(Array(orders.enumerated()), id: \.element.id) { index, order in
                                Rectangle()
                                    .fill(segmentGradient(index))
                                    .frame(width: proxy.size.width * CGFloat(order.segmentRatio(total: total)))
                            }
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 12)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], alignment: .leading, spacing: 8) {
                    if orders.isEmpty {
                        OverviewLegendItem(label: "Chưa có", count: 0)
                    } else {
                        ForEach(orders) { order in
                            OverviewLegendItem(label: order.label, count: order.count)
                        }
                    }
                }
            }
            .padding(13)
        }
        .accessibilityLabel(teamAccessibilityLabel)
    }

    private var teamAccessibilityLabel: String {
        if orders.isEmpty { return "Team Order: chưa có dữ liệu" }
        return "Team Order: " + orders.map { "\($0.label) \($0.count)" }.joined(separator: ", ")
    }

    private func segmentGradient(_ index: Int) -> LinearGradient {
        let palette: [[Color]] = [
            [CHColors.purple, CHColors.blue],
            [CHColors.orange, Color(hex: 0xFF8D3A)],
            [Color(hex: 0x54D494), Color(hex: 0x36BF7C)],
            [Color(hex: 0x8B5CF6), Color(hex: 0xEC4899)]
        ]
        let colors = palette[index % palette.count]
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }
}

private struct OverviewLegendItem: View {
    var label: String
    var count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(CHColors.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text("\(count)")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(CHColors.ink)
        }
    }
}

private struct OverviewEditorWorkloadCard: View {
    var workloads: [OverviewEditorWorkload]

    var body: some View {
        OverviewCard {
            VStack(alignment: .leading, spacing: 8) {
                OverviewPanelTitle("Editor Workload")

                if workloads.isEmpty {
                    Text("Chưa có task trong tháng.")
                        .font(CHTypography.caption)
                        .foregroundStyle(CHColors.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(workloads.enumerated()), id: \.element.id) { index, workload in
                        if index > 0 {
                            Divider()
                                .background(CHColors.line)
                        }
                        OverviewEditorRowView(workload: workload)
                    }
                }
            }
            .padding(13)
        }
        .accessibilityLabel(workloads.isEmpty ? "Editor Workload: chưa có task" : "Editor Workload")
    }
}

private struct OverviewEditorRowView: View {
    var workload: OverviewEditorWorkload

    var body: some View {
        HStack(spacing: 9) {
            OverviewWorkloadAvatar(workload: workload)
            VStack(alignment: .leading, spacing: 5) {
                Text(workload.shortName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(CHColors.ink)
                    .lineLimit(1)
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(workload.buckets.enumerated()), id: \.offset) { _, value in
                        Capsule()
                            .fill(CHColors.primaryGradient)
                            .frame(width: 5, height: miniBarHeight(value))
                    }
                }
                .frame(height: 18, alignment: .bottom)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(workload.taskCount)")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(CHColors.ink)
                Text("task")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(CHColors.muted)
            }
        }
        .padding(.vertical, 6)
        .accessibilityLabel("\(workload.name), \(workload.taskCount) task")
    }

    private func miniBarHeight(_ value: Int) -> CGFloat {
        let maxValue = max(workload.buckets.max() ?? 0, 1)
        return value == 0 ? 4 : max(6, CGFloat(value) / CGFloat(maxValue) * 18)
    }
}

private struct OverviewWorkloadAvatar: View {
    var workload: OverviewEditorWorkload

    private var url: URL? {
        workload.avatarURL
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(avatarFill)

            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        initials
                    }
                }
            } else {
                initials
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1))
        .shadow(color: CHShadow.cardColor.opacity(0.7), radius: 9, y: 5)
        .accessibilityHidden(true)
    }

    private var initials: some View {
        Text(workload.initials)
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(CHColors.ink)
            .frame(width: 38, height: 38)
    }

    private var avatarFill: Color {
        Color(hexString: workload.colorHex) ?? Color(hex: 0xEEF2FA)
    }
}

private struct OverviewBottomMetricsCard: View {
    var dashboard: OverviewDashboard

    var body: some View {
        HStack(spacing: 9) {
            OverviewBottomMetric(
                label: "Completion",
                value: "\(dashboard.completedVideos)/\(dashboard.totalVideos)",
                track: .ratio(dashboard.completionRatio)
            )
            .accessibilityIdentifier("overview.bottom.completion")

            OverviewBottomMetric(
                label: "Shoot load",
                value: "\(dashboard.shootCount)",
                track: dashboard.shootLoadTrack
            )
            .accessibilityIdentifier("overview.bottom.shoot-load")
        }
    }
}

private struct OverviewBottomMetric: View {
    var label: String
    var value: String
    var track: OverviewTrackSemantics

    var body: some View {
        OverviewCard {
            VStack(alignment: .leading, spacing: 9) {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(CHColors.muted)
                Text(value)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(CHColors.ink)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(hex: 0xE5E8F1))
                        if let ratio = track.fillRatio {
                            Capsule()
                                .fill(CHColors.primaryGradient)
                                .frame(width: proxy.size.width * ratio)
                        }
                    }
                }
                .frame(height: 7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .accessibilityLabel("\(label): \(value)")
    }
}

private struct OverviewInlineError: View {
    var message: String
    var retry: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(CHColors.orange)
            Text(message)
                .font(CHTypography.caption)
                .foregroundStyle(CHColors.ink)
                .lineLimit(2)
            Spacer(minLength: 6)
            Button("Thử lại", action: retry)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(CHColors.purple)
        }
        .padding(10)
        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 8)
        .accessibilityIdentifier("overview.inline-error")
    }
}

private struct OverviewPanelTitle: View {
    var title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(CHColors.muted)
            .textCase(.uppercase)
            .tracking(0.4)
    }
}

private struct OverviewCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(CHColors.card)
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.78), lineWidth: 1))
                    .shadow(color: CHShadow.cardColor, radius: 17, y: 12)
            )
    }
}

#if DEBUG
#Preview("Overview") {
    OverviewView(
        viewModel: OverviewViewModel(
            provider: OverviewFixtureProvider(fixture: .visual),
            month: OverviewMonth(year: 2026, month: 8)
        )
    )
    .padding()
    .background(CHColors.appBackground)
}
#endif
