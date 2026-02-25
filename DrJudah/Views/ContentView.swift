import SwiftUI

struct ContentView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            AskJudahView()
                .tabItem {
                    Label("Ask Judah", systemImage: "sparkles")
                }
                .tag(1)

            SyncView()
                .tabItem {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(2)
        }
        .tint(.drJudahBlue)
        .task {
            do {
                try await healthKitManager.requestAuthorization()
                _ = await NotificationManager.shared.requestPermission()
                NotificationManager.shared.scheduleWeeklySummary()
            } catch {}
        }
    }
}
