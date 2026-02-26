import SwiftUI

struct ContentView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2.fill")
                }
                .tag(0)

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "lightbulb.fill")
                }
                .tag(1)

            AskJudahView()
                .tabItem {
                    Label("Ask Judah", systemImage: "sparkles")
                }
                .tag(2)

            VitalsView()
                .tabItem {
                    Label("Vitals", systemImage: "waveform.path.ecg")
                }
                .tag(3)

            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle.fill")
                }
                .tag(4)
        }
        .tint(.drJudahBlue)
        .task {
            do {
                try await healthKitManager.requestAuthorization()
                _ = await NotificationManager.shared.requestPermission()
            } catch {
                print("HealthKit authorization failed: \(error)")
            }
        }
    }
}
