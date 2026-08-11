import SwiftUI

struct MainShellView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var operations: OperationsViewModel

    var body: some View {
        NavigationStack(path: $appState.path) {
            ZStack {
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    AppTopBar(
                        title: title,
                        subtitle: subtitle,
                        rightSystemImage: rightIcon,
                        rightAction: rightAction
                    )

                    ScrollView {
                        selectedScreen
                            .padding(.bottom, 14)
                    }
                    .scrollIndicators(.hidden)
                    .refreshable {
                        await operations.refresh()
                    }

                    AppBottomBar()
                        .padding(.bottom, 6)
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .contentPlan:
                    if appState.can(.contentPlanView) {
                        ContentPlanView()
                    } else {
                        AccessDeniedView()
                    }
                case .users:
                    if PermissionService.canManageUsers(profile: appState.currentProfile) {
                        UsersView()
                    } else {
                        AccessDeniedView()
                    }
                case .notifications:
                    NotificationsView()
                case .taskDetail(let taskId):
                    TaskDetailView(taskId: taskId)
                case .shootDetail(let shootId):
                    ShootDetailView(shootId: shootId)
                case .contentPlanDetail(let itemId):
                    ContentPlanDetailView(itemId: itemId)
                case .userDetail(let userId):
                    UserDetailView(userId: userId)
                }
            }
            .sheet(item: $appState.activeSheet) { sheet in
                sheetView(sheet)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .task {
                await operations.loadCurrentMonth()
            }
        }
    }

    private var title: String {
        switch appState.selectedTab {
        case .dashboard: "Tổng quan"
        case .tasks: "Video tháng"
        case .calendar: "Lịch quay"
        case .profile: "Cá nhân"
        }
    }

    private var subtitle: String {
        switch appState.selectedTab {
        case .dashboard: "Báo cáo công việc theo tháng"
        case .tasks: "Danh sách video task"
        case .calendar: "Lịch quay và livestream"
        case .profile: "Tài khoản và tuỳ chọn"
        }
    }

    private var rightIcon: String {
        switch appState.selectedTab {
        case .dashboard, .profile: "bell"
        case .tasks, .calendar: "plus"
        }
    }

    private func rightAction() {
        switch appState.selectedTab {
        case .dashboard, .profile:
            appState.path.append(.notifications)
        case .tasks:
            appState.activeSheet = .quickCreateTask
        case .calendar:
            operations.selectedShoot = nil
            appState.activeSheet = .shootCreate
        }
    }

    @ViewBuilder
    private var selectedScreen: some View {
        switch appState.selectedTab {
        case .dashboard:
            if appState.can(.dashboardView) {
                DashboardView()
            } else {
                AccessDeniedView()
                    .padding(.horizontal, AppSpacing.screen)
            }
        case .tasks:
            if appState.can(.videoTasksView) {
                TasksView()
            } else {
                AccessDeniedView()
                    .padding(.horizontal, AppSpacing.screen)
            }
        case .calendar:
            if appState.can(.shootsView) {
                CalendarScreenView()
            } else {
                AccessDeniedView()
                    .padding(.horizontal, AppSpacing.screen)
            }
        case .profile:
            ProfileView()
        }
    }

    @ViewBuilder
    private func sheetView(_ sheet: AppSheet) -> some View {
        switch sheet {
        case .quickCreateTask:
            TaskEditorSheet()
        case .taskEdit:
            TaskEditSheet()
        case .linkedTaskAccept:
            LinkedTaskAcceptSheet()
        case .linkedTaskExecution:
            LinkedTaskExecutionSheet()
        case .shootCreate:
            ShootEditorSheet()
        case .shootEdit:
            ShootEditorSheet()
        case .contentPlanCreate:
            ContentPlanEditorSheet()
        case .contentPlanEdit:
            ContentPlanEditorSheet()
        case .adminUserCreate:
            AdminUserEditorSheet(mode: .create)
        case .adminUserEdit:
            AdminUserEditorSheet(mode: .edit)
        case .adminPasswordReset:
            AdminPasswordResetSheet()
        case .profileEdit:
            ProfileEditorSheet()
        case .passwordEdit:
            PasswordEditorSheet()
        }
    }
}
