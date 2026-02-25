import SwiftUI

@main
struct DrJudahApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var syncManager = BackgroundSyncManager()

    init() {
        BackgroundSyncManager.registerBackgroundTasks()
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    ContentView()
                        .environmentObject(authManager)
                        .environmentObject(healthKitManager)
                        .environmentObject(syncManager)
                } else {
                    LoginView()
                        .environmentObject(authManager)
                }
            }
            .onOpenURL { url in
                authManager.handleDeepLink(url: url)
            }
        }
    }

    private func configureAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
