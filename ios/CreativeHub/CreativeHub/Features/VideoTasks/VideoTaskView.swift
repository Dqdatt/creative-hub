import SwiftUI

struct VideoTaskView: View {
    @ObservedObject var viewModel: VideoTaskViewModel
    var isToolsOpen: Bool
    var permissions: VideoTaskPermissions
    var openModule: (ModuleDestination) -> Void
    var isPhase3QAHarnessEnabled: Bool = false
    var showPhase3QAToast: () -> Void = {}

    var body: some View {
        VStack(spacing: 10) {
            if isToolsOpen {
                VideoTaskToolRevealPanel(
                    isOpen: isToolsOpen,
                    viewModel: viewModel,
                    isPhase3QAHarnessEnabled: isPhase3QAHarnessEnabled,
                    showPhase3QAToast: showPhase3QAToast
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            VideoTimeNavigator(viewModel: viewModel)
            videoContent
        }
        .overlay(alignment: .topLeading) {
            VStack(spacing: 0) {
                Text("video.root")
                    .font(.system(size: 1))
                    .foregroundStyle(.clear)
                    .frame(width: 1, height: 1)
                    .accessibilityIdentifier("video.root")
                Text("Video")
                    .font(.system(size: 1))
                    .foregroundStyle(.clear)
                    .frame(width: 1, height: 1)
                Text(isToolsOpen ? "open" : "closed")
                    .font(.system(size: 1))
                    .foregroundStyle(.clear)
                    .frame(width: 1, height: 1)
                    .accessibilityIdentifier("tool-reveal.state.video.\(isToolsOpen ? "open" : "closed")")
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private var videoContent: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            CHStateView(kind: .loading, title: "Đang tải dữ liệu video...")
                .frame(minHeight: 430)
                .accessibilityIdentifier("video.loading")
        case .failed(let message, _):
            CHStateView(
                kind: .error,
                title: "Không thể tải video tháng",
                message: message,
                actionTitle: "Thử lại",
                action: { Task { await viewModel.retry() } }
            )
            .frame(minHeight: 430)
            .accessibilityIdentifier("video.load-error")
        case .loaded:
            VStack(spacing: 9) {
                HStack(alignment: .center) {
                    Text("\(viewModel.visibleTasks.count) video")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(CHColors.muted)
                        .accessibilityIdentifier("video.summary-count")
                    Spacer()
                    if permissions.canCreate {
                        Button {
                            viewModel.openCreate()
                            openModule(.taskCreate)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .heavy))
                                Text("Thêm Task")
                            }
                        }
                        .buttonStyle(VideoPrimaryCompactButtonStyle())
                        .accessibilityIdentifier("video.add")
                    }
                }
                .padding(.horizontal, 2)

                if viewModel.visibleTasks.isEmpty {
                    VideoInlineEmpty(
                        message: viewModel.hasActiveFilters
                            ? "Không tìm thấy task phù hợp."
                            : (permissions.canCreate ? "\(viewModel.periodEmptyMessage) Bấm + Thêm Task để tạo task mới." : viewModel.periodEmptyMessage)
                    )
                    .accessibilityIdentifier(viewModel.hasActiveFilters ? "video.filter-empty" : "video.month-empty")
                } else {
                    LazyVStack(spacing: 9) {
                        ForEach(viewModel.visibleTasks) { task in
                            VideoTaskCard(
                                task: task,
                                permissions: permissions,
                                onOpen: {
                                    guard permissions.canUpdate else { return }
                                    viewModel.open(task: task, permissions: permissions)
                                    openModule(.taskEdit(id: task.id.uuidString))
                                },
                                onDelete: {
                                    guard permissions.canDelete else { return }
                                    viewModel.open(task: task, permissions: permissions)
                                    viewModel.requestDelete()
                                    openModule(.taskEdit(id: task.id.uuidString))
                                }
                            )
                        }
                    }
                    .accessibilityIdentifier("video.task-list")
                }
            }
            .padding(.bottom, 26)
        }
    }
}

private struct VideoTimeNavigator: View {
    @ObservedObject var viewModel: VideoTaskViewModel

    var body: some View {
        CHTimeScopeNavigator(
            scope: viewModel.timeScope,
            monthLabel: viewModel.selectedMonthLabel,
            weekDays: viewModel.weekDays,
            accessibilityPrefix: "video",
            onPrevious: {
                Task {
                    if viewModel.timeScope == .month {
                        await viewModel.shiftMonth(-1)
                    } else {
                        await viewModel.shiftWeek(-1)
                    }
                }
            },
            onNext: {
                Task {
                    if viewModel.timeScope == .month {
                        await viewModel.shiftMonth(1)
                    } else {
                        await viewModel.shiftWeek(1)
                    }
                }
            },
            onSelectScope: { scope in
                Task { await viewModel.selectScope(scope) }
            },
            onSelectDay: { day in
                Task { await viewModel.selectDay(day) }
            }
        )
    }
}

struct VideoTaskToolRevealPanel: View {
    var isOpen: Bool
    @ObservedObject var viewModel: VideoTaskViewModel
    var isPhase3QAHarnessEnabled: Bool = false
    var showPhase3QAToast: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            Text(isOpen ? "open" : "closed")
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("tool-reveal.state.video.\(isOpen ? "open" : "closed")")

            VStack(spacing: 8) {
                searchField
                statusRail
                secondaryFilters
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.white.opacity(0.46))
                    .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Color.white.opacity(0.52), lineWidth: 1))
                    .shadow(color: CHShadow.softColor, radius: 10, y: 7)
            )
            .frame(maxHeight: isOpen ? nil : 0, alignment: .top)
            .opacity(isOpen ? 1 : 0)
            .offset(y: isOpen ? 0 : -7)
            .clipped()
            .allowsHitTesting(isOpen)
            .accessibilityHidden(!isOpen)
        }
        .padding(.bottom, isOpen ? 8 : 0)
        .animation(.timingCurve(0.2, 0.75, 0.25, 1, duration: 0.26), value: isOpen)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(CHColors.purple)
            TextField("Tìm tên video...", text: $viewModel.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(CHTypography.caption)
                .accessibilityIdentifier("tool-reveal.search.video")
        }
        .padding(.horizontal, 11)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.82))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(CHColors.line, lineWidth: 1))
        )
    }

    private var statusRail: some View {
        VideoChipRail {
            ForEach(VideoTaskFilterStatus.allCases) { filter in
                VideoFilterChip(title: filter.label, isActive: viewModel.statusFilter == filter, tint: filter.status?.tint) {
                    viewModel.statusFilter = filter
                }
                .accessibilityIdentifier("video.filter.status.\(filter.rawValue)")
            }
        }
    }

    private var secondaryFilters: some View {
        VStack(spacing: 7) {
            HStack(spacing: 7) {
                VideoSecondaryFilterMenu(
                    title: secondaryLabel(prefix: "Editor", value: selectedEditorLabel),
                    isActive: viewModel.editorFilter != "all",
                    identifier: "video.filter.editor.menu"
                ) {
                    Button("Tất cả editor") { viewModel.editorFilter = "all" }
                        .accessibilityIdentifier("video.filter.editor.all")
                    ForEach(viewModel.editorOptions) { editor in
                        Button(editor.shortName) { viewModel.editorFilter = editor.editorCode }
                            .accessibilityIdentifier("video.filter.editor.\(editor.editorCode)")
                    }
                }

                VideoSecondaryFilterMenu(
                    title: secondaryLabel(prefix: "Order", value: viewModel.orderFilter == "all" ? nil : viewModel.orderFilter),
                    isActive: viewModel.orderFilter != "all",
                    identifier: "video.filter.order.menu"
                ) {
                    Button("Tất cả order") { viewModel.orderFilter = "all" }
                        .accessibilityIdentifier("video.filter.order.all")
                    ForEach(VideoTaskConstants.orderTeams, id: \.self) { team in
                        Button(team) { viewModel.orderFilter = team }
                            .accessibilityIdentifier("video.filter.order.\(team)")
                    }
                }
            }

            HStack(spacing: 7) {
                VideoSecondaryFilterMenu(
                    title: secondaryLabel(prefix: "Thể loại", value: viewModel.categoryFilter == "all" ? nil : viewModel.categoryFilter),
                    isActive: viewModel.categoryFilter != "all",
                    identifier: "video.filter.category.menu"
                ) {
                    Button("Tất cả thể loại") { viewModel.categoryFilter = "all" }
                        .accessibilityIdentifier("video.filter.category.all")
                    ForEach(VideoTaskCategory.allCases) { category in
                        Button(category.rawValue) { viewModel.categoryFilter = category.rawValue }
                            .accessibilityIdentifier("video.filter.category.\(category.rawValue.replacingOccurrences(of: " ", with: "-"))")
                    }
                }

                Spacer(minLength: 0)

                if isPhase3QAHarnessEnabled {
                    Button(action: showPhase3QAToast) {
                        Image(systemName: "bubble.left.and.text.bubble.right")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(CHColors.purple)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.white.opacity(0.82)).overlay(Circle().stroke(CHColors.line)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("phase3.show-toast")
                }
                if viewModel.hasActiveFilters {
                    Button {
                        viewModel.resetFilters()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(CHColors.purple)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.white.opacity(0.82)).overlay(Circle().stroke(CHColors.line)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("video.filter.reset")
                }
            }
        }
    }

    private var selectedEditorLabel: String? {
        guard viewModel.editorFilter != "all" else { return nil }
        return viewModel.editorOptions.first { $0.editorCode == viewModel.editorFilter }?.shortName ?? viewModel.editorFilter
    }

    private func secondaryLabel(prefix: String, value: String?) -> String {
        if let value, !value.isEmpty {
            return "\(prefix) · \(value)"
        }
        return "\(prefix) · Tất cả"
    }
}

private struct VideoChipRail<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                content
            }
        }
    }
}

private struct VideoFilterChip: View {
    var title: String
    var isActive: Bool
    var tint: Color?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let tint {
                    Circle()
                        .fill(tint)
                        .frame(width: 7, height: 7)
                }
                Text(title)
                    .lineLimit(1)
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(isActive ? .white : CHColors.muted)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(
                Capsule(style: .continuous)
                    .fill(isActive ? AnyShapeStyle(CHColors.primaryGradient) : AnyShapeStyle(Color.white.opacity(0.74)))
                    .overlay(Capsule().stroke(isActive ? Color.clear : CHColors.line, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct VideoSecondaryFilterMenu<Content: View>: View {
    var title: String
    var isActive: Bool
    var identifier: String
    @ViewBuilder var content: Content

    var body: some View {
        Menu {
            content
        } label: {
            HStack(spacing: 5) {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .heavy))
            }
            .font(.system(size: 10.5, weight: .bold))
            .foregroundStyle(isActive ? .white : CHColors.muted)
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(
                Capsule(style: .continuous)
                    .fill(isActive ? AnyShapeStyle(CHColors.primaryGradient) : AnyShapeStyle(Color.white.opacity(0.78)))
                    .overlay(Capsule().stroke(isActive ? Color.clear : CHColors.line, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

private struct VideoTaskCard: View {
    var task: VideoTask
    var permissions: VideoTaskPermissions
    var onOpen: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(task.id.uuidString)
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("video.task.\(task.id.uuidString.lowercased())")

            HStack(alignment: .top, spacing: 10) {
                Text("\(task.sequence)")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Color(hex: 0x6872AC))
                    .frame(width: 26, height: 26)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(hex: 0xF0F2FB)))
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(task.title)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(CHColors.ink)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if permissions.canUpdate {
                                    onOpen()
                                }
                            }
                        HStack(spacing: 6) {
                            if task.isResultLinkActionable, let url = URL(string: task.resultLink) {
                                Link(destination: url) {
                                    Image(systemName: "link")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(CHColors.purple)
                                        .frame(width: 32, height: 32)
                                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color(hex: 0xF4F1FF)))
                                }
                                .accessibilityIdentifier("video.task.link.\(task.id.uuidString)")
                            }
                            if permissions.canDelete {
                                Button(action: onDelete) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(CHColors.red)
                                        .frame(width: 32, height: 32)
                                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color(hex: 0xFFF1F2)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("video.task.delete.\(task.id.uuidString)")
                            }
                        }
                    }

                    HStack(spacing: 7) {
                        VideoEditorChip(name: task.editorDisplayName, initials: String(task.editorDisplayName.prefix(1)).uppercased())
                        VideoTinyBadge(title: task.orderTeam.isEmpty ? "-" : task.orderTeam)
                        VideoCategoryBadge(category: task.category)
                        VideoStatusBadge(status: task.status)
                        if task.priority == .urgent {
                            VideoTinyBadge(title: "Gấp", tint: CHColors.red, background: Color(hex: 0xFFE9EC))
                        }
                    }

                    HStack(spacing: 10) {
                        VideoDatePill(label: "Nhận", value: task.receiveDate)
                        VideoDatePill(label: "Trả", value: task.returnDate)
                        VideoDatePill(label: "Air", value: task.airDate, highlighted: true)
                    }

                    if !task.resize.isEmpty || !task.note.isEmpty || task.isLinked {
                        HStack(spacing: 6) {
                            Image(systemName: task.isLinked ? "link.badge.plus" : "note.text")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(CHColors.muted)
                            Text(summary)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(CHColors.muted)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(task.status == .done ? 0.74 : 0.84))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(task.priority == .urgent ? CHColors.red.opacity(0.25) : Color.white.opacity(0.78), lineWidth: 1)
                    )
                    .shadow(color: CHShadow.softColor, radius: 13, y: 8)
            )
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(task.status == .done ? CHColors.green : task.priority == .urgent ? CHColors.red : task.status.tint)
                    .frame(width: 3)
                    .padding(.vertical, 12)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if permissions.canUpdate {
                onOpen()
            }
        }
    }

    private var summary: String {
        let prefix = task.isLinked ? "Linked Content Plan" : (task.resize.isEmpty ? "" : "Resize \(task.resize)")
        if prefix.isEmpty { return task.note }
        if task.note.isEmpty { return prefix }
        return "\(prefix) · \(task.note)"
    }
}

private struct VideoEditorChip: View {
    var name: String
    var initials: String

    var body: some View {
        HStack(spacing: 5) {
            CHAvatar(initials: initials, size: 24)
            Text(name)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(CHColors.ink)
                .lineLimit(1)
        }
    }
}

private struct VideoTinyBadge: View {
    var title: String
    var tint: Color = Color(hex: 0x303746)
    var background: Color = Color(hex: 0xF2F3F5)

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(background))
    }
}

private struct VideoStatusBadge: View {
    var status: VideoTaskStatus

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(status.tint)
                .frame(width: 6, height: 6)
            Text(status.rawValue)
        }
        .font(.system(size: 10, weight: .heavy))
        .foregroundStyle(status.tint)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(status.softBackground))
    }
}

private struct VideoCategoryBadge: View {
    var category: VideoTaskCategory

    var body: some View {
        Text(category.rawValue)
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(category.tint)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(category.softBackground))
    }
}

private struct VideoDatePill: View {
    var label: String
    var value: String?
    var highlighted = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.system(size: 10, weight: .bold))
            Text("\(label) \(VideoTaskDateFormatter.display(value))")
        }
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundStyle(highlighted ? CHColors.purple : CHColors.muted)
        .lineLimit(1)
    }
}

private struct VideoInlineEmpty: View {
    var message: String

    var body: some View {
        Text(message)
            .font(CHTypography.caption)
            .foregroundStyle(CHColors.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.76))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.72), lineWidth: 1))
            )
    }
}

private struct VideoPrimaryCompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(CHColors.primaryGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color(red: 80 / 255, green: 92 / 255, blue: 255 / 255).opacity(0.20), radius: 9, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
