import SwiftUI

@main
struct DrJudahApp: App {
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var syncManager = BackgroundSyncManager()
    @StateObject private var apiManager = APIManager()

    init() {
        BackgroundSyncManager.registerBackgroundTasks()
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitManager)
                .environmentObject(syncManager)
                .environmentObject(apiManager)
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
