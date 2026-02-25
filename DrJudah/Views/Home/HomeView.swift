import SwiftUI

struct HomeView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Premium gradient header
                    headerSection

                    // AI Insight Cards
                    insightCards
                        .padding(.horizontal)

                    // Live Vitals
                    liveVitalsSection

                    // Today's Workouts
                    if !healthKitManager.recentWorkouts.isEmpty {
                        workoutsSection
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .refreshable {
                await healthKitManager.fetchAllData()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greeting)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(Date().formatted(date: .complete, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "1E40AF"),
                    Color(hex: "3B82F6"),
                    Color(hex: "6366F1"),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .padding(.horizontal)
        .shadow(color: Color(hex: "3B82F6").opacity(0.3), radius: 16, y: 8)
    }

    // MARK: - AI Insight Cards

    private var insightCards: some View {
        VStack(spacing: 12) {
            // What's Changed / Attention cards
            let attentionInsights = healthKitManager.insights.filter { $0.severity >= .attention }
            let infoInsights = healthKitManager.insights.filter { $0.severity == .info }

            if !attentionInsights.isEmpty {
                InsightCardView(
                    title: "Attention Needed",
                    icon: "exclamationmark.triangle.fill",
                    accentColor: Color(hex: "EF4444"),
                    gradientColors: [Color(hex: "FEF2F2"), Color(hex: "FEE2E2")],
                    insights: attentionInsights
                )
            }

            if !infoInsights.isEmpty {
                InsightCardView(
                    title: "What's Changed",
                    icon: "sparkles",
                    accentColor: Color(hex: "3B82F6"),
                    gradientColors: [Color(hex: "EFF6FF"), Color(hex: "DBEAFE")],
                    insights: infoInsights
                )
            }
        }
    }

    // MARK: - Live Vitals

    private var liveVitalsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(hex: "3B82F6"))
                Text("Live Vitals")
                    .font(.title3.bold())
            }
            .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ], spacing: 10) {
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

                if healthKitManager.todayHealth.bloodPressureSystolic > 0 {
                    VitalCard(
                        icon: "heart.circle.fill",
                        title: "Blood Pressure",
                        value: "\(Int(healthKitManager.todayHealth.bloodPressureSystolic))/\(Int(healthKitManager.todayHealth.bloodPressureDiastolic))",
                        unit: "mmHg",
                        trend: nil,
                        sparkline: healthKitManager.todayHealth.systolicHistory.map { $0.1 },
                        color: Color(hex: "DC2626")
                    )
                } else {
                    VitalCard(
                        icon: "heart.circle.fill",
                        title: "Blood Pressure",
                        value: "--/--",
                        unit: "mmHg",
                        trend: nil,
                        sparkline: [],
                        color: Color(hex: "DC2626")
                    )
                }

                if healthKitManager.todayHealth.bloodGlucose > 0 {
                    VitalCard(
                        icon: "drop.fill",
                        title: "Glucose",
                        value: formatNumber(healthKitManager.todayHealth.bloodGlucose),
                        unit: "mg/dL",
                        trend: trendDelta(
                            current: healthKitManager.todayHealth.bloodGlucose,
                            average: healthKitManager.todayHealth.avgBloodGlucose,
                            invertColor: true
                        ),
                        sparkline: healthKitManager.todayHealth.bloodGlucoseHistory.map { $0.1 },
                        color: .orange
                    )
                } else {
                    VitalCard(
                        icon: "drop.fill",
                        title: "Glucose",
                        value: "--",
                        unit: "mg/dL",
                        trend: nil,
                        sparkline: [],
                        color: .orange
                    )
                }

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
        }
    }

    // MARK: - Workouts

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
                Text("Today's Workouts")
                    .font(.title3.bold())
            }
            .padding(.horizontal)

            ForEach(healthKitManager.recentWorkouts) { workout in
                WorkoutCard(workout: workout)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Helpers

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning, Max"
        case 12..<17: return "Good afternoon, Max"
        case 17..<22: return "Good evening, Max"
        default: return "Hello, Max"
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
}

// MARK: - Insight Card Component

struct InsightCardView: View {
    let title: String
    let icon: String
    let accentColor: Color
    let gradientColors: [Color]
    let insights: [HealthInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.bold())
                    .foregroundStyle(accentColor)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(accentColor)
            }

            ForEach(insights) { insight in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: insight.icon)
                        .font(.body)
                        .foregroundStyle(insightColor(insight.color))
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(insight.title)
                            .font(.subheadline.bold())
                        Text(insight.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accentColor.opacity(0.15), lineWidth: 1)
        )
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
