import SwiftUI

@main
struct CreativeHubApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(router)
        }
    }
}
