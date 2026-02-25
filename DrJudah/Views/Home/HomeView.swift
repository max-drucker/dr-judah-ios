import SwiftUI

struct HomeView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Greeting Header
                    GradientHeader(
                        greeting: greeting,
                        subtitle: Date().formatted(date: .complete, time: .omitted)
                    )

                    // Health Score
                    HealthScoreView(score: healthKitManager.healthScore)
                        .padding(.horizontal)

                    // Vitals Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                    ], spacing: 12) {
                        VitalCard(
                            icon: "figure.walk",
                            title: "Steps",
                            value: formatNumber(healthKitManager.todayHealth.steps),
                            unit: "",
                            trend: trendDelta(
                                current: healthKitManager.todayHealth.steps,
                                average: healthKitManager.todayHealth.avgSteps
                            ),
                            sparkline: healthKitManager.todayHealth.stepsHistory.map { $0.1 },
                            color: .green
                        )

                        VitalCard(
                            icon: "heart.fill",
                            title: "Resting HR",
                            value: formatNumber(healthKitManager.todayHealth.restingHeartRate),
                            unit: "bpm",
                            trend: trendDelta(
                                current: healthKitManager.todayHealth.restingHeartRate,
                                average: healthKitManager.todayHealth.avgRestingHR,
                                invertColor: true
                            ),
                            sparkline: healthKitManager.todayHealth.restingHRHistory.map { $0.1 },
                            color: .red
                        )

                        VitalCard(
                            icon: "waveform.path.ecg",
                            title: "HRV",
                            value: formatNumber(healthKitManager.todayHealth.hrv),
                            unit: "ms",
                            trend: trendDelta(
                                current: healthKitManager.todayHealth.hrv,
                                average: healthKitManager.todayHealth.avgHRV
                            ),
                            sparkline: healthKitManager.todayHealth.hrvHistory.map { $0.1 },
                            color: .purple
                        )

                        VitalCard(
                            icon: "flame.fill",
                            title: "Active Cal",
                            value: formatNumber(healthKitManager.todayHealth.activeCalories),
                            unit: "kcal",
                            trend: trendDelta(
                                current: healthKitManager.todayHealth.activeCalories,
                                average: healthKitManager.todayHealth.avgActiveCalories
                            ),
                            sparkline: healthKitManager.todayHealth.activeCaloriesHistory.map { $0.1 },
                            color: .orange
                        )

                        VitalCard(
                            icon: "figure.run",
                            title: "Exercise",
                            value: formatNumber(healthKitManager.todayHealth.exerciseMinutes),
                            unit: "min",
                            trend: nil,
                            sparkline: healthKitManager.todayHealth.exerciseMinutesHistory.map { $0.1 },
                            color: .cyan
                        )

                        VitalCard(
                            icon: "lungs.fill",
                            title: "SpO₂",
                            value: healthKitManager.todayHealth.bloodOxygen > 0
                                ? String(format: "%.0f", healthKitManager.todayHealth.bloodOxygen)
                                : "--",
                            unit: "%",
                            trend: nil,
                            sparkline: [],
                            color: .blue
                        )
                    }
                    .padding(.horizontal)

                    // Workouts
                    if !healthKitManager.recentWorkouts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Today's Workouts")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(healthKitManager.recentWorkouts) { workout in
                                WorkoutCard(workout: workout)
                                    .padding(.horizontal)
                            }
                        }
                    }

                    // Insights
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Insights from Dr. Judah")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(healthKitManager.insights) { insight in
                            HStack(spacing: 12) {
                                Image(systemName: insight.icon)
                                    .font(.title3)
                                    .foregroundStyle(insightColor(insight.color))
                                    .frame(width: 36)

                                Text(insight.message)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
            .refreshable {
                await healthKitManager.fetchAllData()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = authManager.currentUser?.firstName ?? "there"
        switch hour {
        case 5..<12: return "Good morning, \(name)"
        case 12..<17: return "Good afternoon, \(name)"
        case 17..<22: return "Good evening, \(name)"
        default: return "Hello, \(name)"
        }
    }

    private func formatNumber(_ value: Double) -> String {
        if value == 0 { return "--" }
        if value >= 1000 {
            return String(format: "%.0f", value)
        }
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func trendDelta(current: Double, average: Double, invertColor: Bool = false) -> TrendInfo? {
        guard current > 0 && average > 0 else { return nil }
        let delta = current - average
        let pct = (delta / average) * 100
        return TrendInfo(delta: delta, percentage: pct, invertColor: invertColor)
    }

    private func insightColor(_ name: String) -> Color {
        switch name {
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "blue": return .drJudahBlue
        default: return .primary
        }
    }
}

struct TrendInfo {
    let delta: Double
    let percentage: Double
    let invertColor: Bool

    var isPositive: Bool { invertColor ? delta < 0 : delta > 0 }
    var arrow: String { delta > 0 ? "↑" : "↓" }
    var color: Color { isPositive ? .green : (abs(percentage) > 10 ? .red : .orange) }
    var text: String { "\(arrow) \(String(format: "%.0f", abs(percentage)))%" }
}
