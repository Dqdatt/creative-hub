import SwiftUI

@main
struct CreativeHubOpsApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var operationsViewModel = OperationsViewModel()
    @StateObject private var notificationsViewModel = NotificationsViewModel()
    @StateObject private var notificationRealtimeManager = NotificationRealtimeManager()
    @StateObject private var adminUsersViewModel = AdminUsersViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(authViewModel)
                .environmentObject(operationsViewModel)
                .environmentObject(notificationsViewModel)
                .environmentObject(notificationRealtimeManager)
                .environmentObject(adminUsersViewModel)
                .preferredColorScheme(appState.preferredColorScheme)
        }
    }
}
