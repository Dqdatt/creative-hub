import SwiftUI

struct ContentPlanView: View {
    @ObservedObject var viewModel: ContentPlanViewModel
    var isToolsOpen: Bool
    var permissions: ContentPlanPermissions
    var openModule: (ModuleDestination) -> Void

    var body: some View {
        VStack(spacing: 10) {
            if isToolsOpen {
                ContentPlanToolRevealPanel(isOpen: isToolsOpen, viewModel: viewModel)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            ContentPlanTimeNavigator(viewModel: viewModel)
            content
        }
        .overlay(alignment: .topLeading) {
            Text("content.root")
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("content.root")
            Text(isToolsOpen ? "open" : "closed")
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("tool-reveal.state.content.\(isToolsOpen ? "open" : "closed")")
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            CHStateView(kind: .loading, title: "Đang tải Content Plan...")
                .frame(minHeight: 430)
                .accessibilityIdentifier("content.loading")
        case .failed(let message, _):
            CHStateView(
                kind: .error,
                title: "Không thể tải Content Plan",
                message: message,
                actionTitle: "Thử lại",
                action: { Task { await viewModel.retry() } }
            )
            .frame(minHeight: 430)
            .accessibilityIdentifier("content.load-error")
        case .loaded:
            VStack(spacing: 9) {
                HStack(alignment: .center) {
                    Text("\(viewModel.visibleItems.count) dòng")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(CHColors.muted)
                        .accessibilityIdentifier("content.summary-count")
                    Spacer()
                    if permissions.canCreate {
                        Button {
                            viewModel.openCreate()
                            openModule(.contentCreate)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .heavy))
                                Text("Thêm dòng")
                            }
                        }
                        .buttonStyle(ContentPlanPrimaryCompactButtonStyle())
                        .accessibilityIdentifier("content.add")
                    }
                }
                .padding(.horizontal, 2)

                if viewModel.visibleItems.isEmpty {
                    ContentPlanInlineEmpty(
                        message: viewModel.hasActiveFilters
                            ? "Không có lịch air phù hợp."
                            : (permissions.canCreate ? "\(viewModel.periodEmptyMessage) Bấm + Thêm dòng để tạo lịch air mới." : viewModel.periodEmptyMessage)
                    )
                    .accessibilityIdentifier(viewModel.hasActiveFilters ? "content.filter-empty" : "content.month-empty")
                } else {
                    LazyVStack(spacing: 9) {
                        ForEach(viewModel.visibleItems) { item in
                            ContentPlanCard(
                                item: item,
                                editor: viewModel.editorOptions.first { $0.editorCode == item.editorCode },
                                canDelete: permissions.canDelete,
                                onOpen: {
                                    viewModel.open(item: item, permissions: permissions)
                                    openModule(.contentEdit(id: item.id.uuidString))
                                },
                                onDelete: {
                                    viewModel.open(item: item, permissions: permissions)
                                    viewModel.requestDelete()
                                    openModule(.contentEdit(id: item.id.uuidString))
                                }
                            )
                        }
                    }
                    .padding(.bottom, 26)
                    .accessibilityIdentifier("content.plan-list")
                }
            }
        }
    }
}

private struct ContentPlanTimeNavigator: View {
    @ObservedObject var viewModel: ContentPlanViewModel

    var body: some View {
        CHTimeScopeNavigator(
            scope: viewModel.timeScope,
            monthLabel: viewModel.selectedMonthLabel,
            weekDays: viewModel.weekDays,
            accessibilityPrefix: "content",
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

struct ContentPlanToolRevealPanel: View {
    var isOpen: Bool
    @ObservedObject var viewModel: ContentPlanViewModel

    var body: some View {
        VStack(spacing: 0) {
            Text(isOpen ? "open" : "closed")
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("tool-reveal.state.content.\(isOpen ? "open" : "closed")")

            VStack(spacing: 8) {
                searchField
                categoryRail
                editorFilterRow
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
                .accessibilityIdentifier("tool-reveal.search.content")
        }
        .padding(.horizontal, 11)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.82))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(CHColors.line, lineWidth: 1))
        )
    }

    private var categoryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(ContentPlanFilterCategory.canonicalRailOrder) { filter in
                    Button {
                        viewModel.categoryFilter = filter
                    } label: {
                        HStack(spacing: 6) {
                            if let category = filter.category {
                                Circle()
                                    .fill(category.tint)
                                    .frame(width: 7, height: 7)
                            }
                            Text(filter.label)
                                .lineLimit(1)
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(viewModel.categoryFilter == filter ? .white : CHColors.muted)
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(
                            Capsule(style: .continuous)
                                .fill(viewModel.categoryFilter == filter ? AnyShapeStyle(CHColors.primaryGradient) : AnyShapeStyle(Color.white.opacity(0.74)))
                                .overlay(Capsule().stroke(viewModel.categoryFilter == filter ? Color.clear : CHColors.line, lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("content.filter.category.\(filter.rawValue)")
                }
            }
        }
        .accessibilityIdentifier("content.filter.category.rail")
    }

    private var editorFilterRow: some View {
        HStack(spacing: 7) {
            ContentSecondaryFilterMenu(
                title: secondaryLabel(prefix: "Editor", value: selectedEditorLabel),
                isActive: viewModel.editorFilter != "all",
                identifier: "content.filter.editor.menu"
            ) {
                Button("Tất cả editor") { viewModel.editorFilter = "all" }
                    .accessibilityIdentifier("content.filter.editor.all")
                ForEach(viewModel.editorOptions) { editor in
                    Button(editor.shortName) { viewModel.editorFilter = editor.editorCode }
                        .accessibilityIdentifier("content.filter.editor.\(editor.editorCode)")
                }
            }

            Spacer(minLength: 0)

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
                .accessibilityIdentifier("content.filter.reset")
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

private struct ContentSecondaryFilterMenu<Content: View>: View {
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

private struct ContentPlanCard: View {
    var item: ContentPlanItem
    var editor: ContentPlanEditorOption?
    var canDelete: Bool
    var onOpen: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(item.id.uuidString)
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("content.plan.\(item.id.uuidString)")

            HStack(alignment: .top, spacing: 11) {
                VStack(spacing: 1) {
                    Text(dayLabel)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(CHColors.ink)
                    Text("Air")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(CHColors.green)
                }
                .frame(width: 50, height: 54)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: 0xF2F8F5)))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(CHColors.ink)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture(perform: onOpen)

                        HStack(spacing: 6) {
                            if item.hasSafeLink, let url = URL(string: item.link) {
                                Link(destination: url) {
                                    Image(systemName: "link")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(CHColors.purple)
                                        .frame(width: 32, height: 32)
                                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color(hex: 0xF4F1FF)))
                                }
                                .accessibilityIdentifier("content.plan.link.\(item.id.uuidString)")
                            }
                            if canDelete {
                                Button(action: onDelete) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(CHColors.red)
                                        .frame(width: 32, height: 32)
                                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color(hex: 0xFFF1F2)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("content.plan.delete.\(item.id.uuidString)")
                            }
                        }
                    }

                    HStack(spacing: 7) {
                        ContentCategoryBadge(category: item.category)
                        ContentPlanTinyBadge(title: item.editorDisplayName)
                        ContentPlanTaskBadge(item: item)
                    }

                    if !item.note.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "note.text")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(CHColors.muted)
                            Text(item.note)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(CHColors.muted)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(item.hasSafeLink ? 0.74 : 0.84))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.78), lineWidth: 1))
                    .shadow(color: CHShadow.softColor, radius: 13, y: 8)
            )
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }

    private var dayLabel: String {
        let parts = item.airDate.split(separator: "-")
        guard parts.count == 3, let day = Int(parts[2]) else { return "--" }
        return String(format: "%02d", day)
    }
}

private struct ContentCategoryBadge: View {
    var category: ContentPlanCategory

    var body: some View {
        Text(category.rawValue)
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(category.tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(category.softBackground))
    }
}

private struct ContentPlanTinyBadge: View {
    var title: String

    var body: some View {
        Text(title.isEmpty ? "Chưa phân công" : title)
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(Color(hex: 0x303746))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: 0xF2F3F5)))
    }
}

private struct ContentPlanTaskBadge: View {
    var item: ContentPlanItem

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 9, weight: .heavy))
            Text(item.taskStateLabel)
        }
        .font(.system(size: 10, weight: .heavy))
        .foregroundStyle(foreground)
        .lineLimit(1)
        .minimumScaleFactor(0.84)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(background))
        .accessibilityIdentifier("content.plan.task-state.\(item.id.uuidString)")
    }

    private var iconName: String {
        if !item.category.canCreateVideoTask { return "nosign" }
        if item.hasLinkedTask { return "link.badge.plus" }
        if item.hasInconsistentMissingLinkedTask { return "exclamationmark.triangle.fill" }
        return "doc.text"
    }

    private var foreground: Color {
        if !item.category.canCreateVideoTask { return CHColors.orange }
        if item.hasLinkedTask { return CHColors.green }
        if item.hasInconsistentMissingLinkedTask { return CHColors.red }
        return CHColors.muted
    }

    private var background: Color {
        if !item.category.canCreateVideoTask { return Color(hex: 0xFFF3DF) }
        if item.hasLinkedTask { return Color(hex: 0xE6F8EF) }
        if item.hasInconsistentMissingLinkedTask { return Color(hex: 0xFFECEE) }
        return Color(hex: 0xF2F3F5)
    }
}

private struct ContentPlanInlineEmpty: View {
    var message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(CHColors.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.78))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.72), lineWidth: 1))
                    .shadow(color: CHShadow.softColor, radius: 12, y: 8)
            )
    }
}

private struct ContentPlanPrimaryCompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(CHColors.primaryGradient, in: Capsule(style: .continuous))
            .shadow(color: CHColors.purple.opacity(0.20), radius: 9, y: 7)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
