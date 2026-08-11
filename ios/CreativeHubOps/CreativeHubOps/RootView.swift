import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var operationsViewModel: OperationsViewModel
    @EnvironmentObject private var notificationsViewModel: NotificationsViewModel
    @EnvironmentObject private var notificationRealtimeManager: NotificationRealtimeManager
    @EnvironmentObject private var adminUsersViewModel: AdminUsersViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if authViewModel.isCheckingSession {
                LoadingStateView(message: "Đang kiểm tra phiên đăng nhập...")
            } else if appState.isAuthenticated {
                MainShellView()
            } else {
                LoginView()
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .task {
            await authViewModel.bootstrap(appState: appState)
        }
        .onChange(of: appState.currentProfile?.id) { previousProfileId, profileId in
            if previousProfileId != nil, previousProfileId != profileId {
                operationsViewModel.clearForAccountSwitch()
                adminUsersViewModel.clearForAccountSwitch()
                notificationsViewModel.clearForLogout()
                notificationRealtimeManager.stop()
            }

            if let profileId {
                notificationRealtimeManager.start(profileId: profileId, notifications: notificationsViewModel)
            } else {
                operationsViewModel.clearForAccountSwitch()
                adminUsersViewModel.clearForAccountSwitch()
                notificationsViewModel.clearForLogout()
                notificationRealtimeManager.stop()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            notificationRealtimeManager.reconnectIfNeeded(
                profileId: appState.currentProfile?.id,
                notifications: notificationsViewModel
            )
        }
    }
}
