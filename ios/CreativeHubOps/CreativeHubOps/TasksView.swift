import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var operations: OperationsViewModel
    @State private var query = ""
    @State private var filter = "Tất cả"
    private let filters = ["Tất cả", "Đang làm", "Đã xong", "Chờ"]

    var body: some View {
        VStack(spacing: 12) {
            searchField
            segmented
            stateContent
        }
        .padding(.top, 8)
    }

    private var filteredTasks: [VideoTask] {
        operations.tasks.filter { task in
            let matchesFilter = filter == "Tất cả" || task.status.rawValue == filter
            let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesQuery = cleanQuery.isEmpty ||
                task.title.localizedCaseInsensitiveContains(cleanQuery) ||
                task.orderTeam.localizedCaseInsensitiveContains(cleanQuery) ||
                task.category.localizedCaseInsensitiveContains(cleanQuery)
            return matchesFilter && matchesQuery
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        if operations.isLoading {
            AppCard {
                LoadingStateView(message: "Đang tải video task...")
            }
            .padding(.horizontal, AppSpacing.screen)
        } else if let error = operations.errorMessage {
            ErrorStateView(title: "Không thể tải video task", message: error) {
                Task { await operations.refresh() }
            }
            .padding(.horizontal, AppSpacing.screen)
        } else if filteredTasks.isEmpty {
            AppCard {
                EmptyStateView(title: "Không có video task", message: "Thử đổi bộ lọc hoặc kéo xuống để tải lại.")
            }
            .padding(.horizontal, AppSpacing.screen)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(filteredTasks) { task in
                    taskRow(task)
                }
            }
            .padding(.horizontal, AppSpacing.screen)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColors.secondaryText)
            TextField("Tìm video task, phòng ban...", text: $query)
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(AppColors.chip)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.search, style: .continuous))
        .padding(.horizontal, AppSpacing.screen)
    }

    private var segmented: some View {
        HStack(spacing: 2) {
            ForEach(filters, id: \.self) { item in
                Button {
                    filter = item
                } label: {
                    Text(item)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(filter == item ? AppColors.text : AppColors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(filter == item ? .white : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }
        }
        .padding(3)
        .background(AppColors.chip)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, AppSpacing.screen)
    }

    private func taskRow(_ task: VideoTask) -> some View {
        Button {
            operations.selectedTask = task
            appState.path.append(.taskDetail(task.id))
        } label: {
            AppCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(task.title)
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(AppColors.text)
                                .lineLimit(2)
                            Text([task.orderTeam, task.category].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AppColors.secondaryText)
                        }
                        Spacer()
                        StatusBadge(status: task.status)
                    }

                    HStack(spacing: 8) {
                        InfoPill(icon: "calendar", text: "Air \(AppDateFormatter.shortDisplay(task.airDate))")
                        if task.priority == "Gấp" {
                            InfoPill(icon: "bolt.fill", text: "Gấp", tint: AppColors.danger)
                        }
                        if !task.resizeRequirements.isEmpty {
                            InfoPill(icon: "arrow.up.left.and.arrow.down.right", text: task.resizeRequirements)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
