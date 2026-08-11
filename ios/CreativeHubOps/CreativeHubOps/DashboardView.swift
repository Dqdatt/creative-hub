import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var operations: OperationsViewModel

    var body: some View {
        let summary = operations.dashboardSummary

        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tháng \(operations.monthRange.value)")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(AppColors.secondaryText)
                    Text("Xin chào!")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(AppColors.text)
                }
                Spacer()
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.top, 6)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                kpi("\(summary.totalTasks)", "Tổng video task", "video", AppColors.accent)
                kpi("\(summary.completedTasks)", "Đã hoàn thành", "checkmark.circle", AppColors.success)
                kpi("\(summary.inProgressTasks)", "Đang thực hiện", "play.circle", AppColors.warning)
                kpi("\(summary.pendingTasks)", "Chờ nghiệm thu", "clock", AppColors.accent)
            }
            .padding(.horizontal, AppSpacing.screen)

            AppCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Tiến độ tháng")
                            .font(.system(size: 14, weight: .bold))
                        Spacer()
                        Text("\(Int(summary.progress * 100))%")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(AppColors.accent)
                    }
                    ProgressView(value: summary.progress)
                        .tint(AppColors.accent)
                }
            }
            .padding(.horizontal, AppSpacing.screen)

            stateContent(summary: summary)
        }
    }

    @ViewBuilder
    private func stateContent(summary: DashboardSummary) -> some View {
        if operations.isLoading {
            AppCard {
                LoadingStateView(message: "Đang tải dashboard...")
            }
            .padding(.horizontal, AppSpacing.screen)
        } else if let error = operations.errorMessage {
            ErrorStateView(title: "Không thể tải dashboard", message: error) {
                Task { await operations.refresh() }
            }
            .padding(.horizontal, AppSpacing.screen)
        } else if summary.totalTasks == 0 && summary.shoots.isEmpty {
            AppCard {
                EmptyStateView(title: "Chưa có dữ liệu tháng này", message: "Kéo xuống để tải lại khi Supabase đã có dữ liệu.")
            }
            .padding(.horizontal, AppSpacing.screen)
        } else {
            AppCard {
                VStack(alignment: .leading, spacing: 14) {
                    sectionTitle("Việc sắp tới")
                    ForEach(summary.upcomingTasks) { task in
                        Button {
                            operations.selectedTask = task
                            appState.path.append(.taskDetail(task.id))
                        } label: {
                            dashboardTaskRow(task)
                        }
                        .buttonStyle(.plain)
                    }
                    if summary.upcomingTasks.isEmpty {
                        Text("Không còn video task đang mở.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.secondaryText)
                    }

                    Divider()
                    sectionTitle("Lịch quay")
                    ForEach(summary.upcomingShoots) { shoot in
                        Button {
                            operations.selectedShoot = shoot
                            appState.path.append(.shootDetail(shoot.id))
                        } label: {
                            dashboardShootRow(shoot)
                        }
                        .buttonStyle(.plain)
                    }
                    if summary.upcomingShoots.isEmpty {
                        Text("Không có lịch quay trong tháng.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screen)

            editorWorkloadSection(summary: summary)
        }
    }

    private func kpi(_ value: String, _ label: String, _ image: String, _ color: Color) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: image)
                    .foregroundStyle(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(value)
                    .font(.system(size: 25, weight: .black))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 92, alignment: .topLeading)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .black))
            .foregroundStyle(AppColors.text)
    }

    private func dashboardTaskRow(_ task: VideoTask) -> some View {
        HStack(spacing: 10) {
            StatusDot(status: task.status)
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)
                Text("\(task.category) · Air \(AppDateFormatter.shortDisplay(task.airDate))")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(AppColors.secondaryText)
            }
            Spacer()
            StatusBadge(status: task.status)
        }
    }

    private func dashboardShootRow(_ shoot: ShootSchedule) -> some View {
        HStack(spacing: 10) {
            Image(systemName: shoot.type == "livestream" ? "dot.radiowaves.left.and.right" : "calendar")
                .foregroundStyle(AppColors.accent)
                .frame(width: 30, height: 30)
                .background(AppColors.accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(shoot.location.isEmpty ? shoot.typeLabel : shoot.location)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                Text("\(AppDateFormatter.shortDisplay(shoot.date)) · \(shoot.timeSlot.isEmpty ? shoot.typeLabel : shoot.timeSlot)")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(AppColors.secondaryText)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func editorWorkloadSection(summary: DashboardSummary) -> some View {
        if !summary.editors.isEmpty {
            AppCard {
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("Task theo từng người")
                    ForEach(summary.editorWorkloads) { workload in
                        VStack(spacing: 8) {
                            HStack(spacing: 10) {
                                Text(workload.editor.initial)
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(AppColors.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(workload.editor.shortName)
                                        .font(.system(size: 13, weight: .black))
                                        .foregroundStyle(AppColors.text)
                                    Text(workload.editor.role)
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundStyle(AppColors.secondaryText)
                                }
                                Spacer()
                                Text("\(workload.total)")
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundStyle(AppColors.accent)
                            }
                            HStack {
                                miniMetric("Dài", workload.longVideoCount)
                                miniMetric("Motion", workload.motionCount)
                                miniMetric("Ads", workload.adsCount)
                                miniMetric("Resize", workload.resizeCount)
                                miniMetric("Quay", workload.shootCount)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screen)
        }
    }

    private func miniMetric(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(AppColors.text)
            Text(label)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(AppColors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(AppColors.chip)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
