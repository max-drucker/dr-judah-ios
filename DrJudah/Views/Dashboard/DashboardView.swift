import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var apiManager: APIManager

    @State private var showWebSheet = false
    @State private var webURL: URL?
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection

                    // Critical alerts
                    if !apiManager.criticalAlerts.isEmpty {
                        criticalAlertsSection
                            .padding(.horizontal)
                    }

                    // Health Status Grid
                    healthStatusGrid
                        .padding(.horizontal)

                    // Key Signals
                    if !apiManager.signals.isEmpty {
                        signalsSection
                    }

                    // Live Vitals
                    liveVitalsSection

                    // Trend Charts
                    trendChartsSection
                        .padding(.horizontal)

                    // Today's Workouts
                    if !healthKitManager.recentWorkouts.isEmpty {
                        workoutsSection
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .refreshable {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                apiManager.invalidateCache()
                async let api: () = apiManager.fetchAll()
                async let hk: () = healthKitManager.fetchAllData()
                _ = await (api, hk)
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showWebSheet) {
                if let url = webURL {
                    WebViewSheet(url: url)
                }
            }
            .task {
                await apiManager.fetchAll()
            }
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

            if apiManager.isLoading {
                HStack(spacing: 6) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.7)
                    Text("Updating…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 4)
            }
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
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal)
        .shadow(color: Color(hex: "3B82F6").opacity(0.3), radius: 16, y: 8)
    }

    // MARK: - Critical Alerts

    private var criticalAlertsSection: some View {
        VStack(spacing: 8) {
            ForEach(apiManager.criticalAlerts) { alert in
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundStyle(alertColor(alert.severityColor))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.title)
                            .font(.subheadline.bold())
                        Text(alert.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(alertColor(alert.severityColor).opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(alertColor(alert.severityColor).opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Health Status Grid

    private var healthStatusGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(hex: "3B82F6"))
                Text("Health Status")
                    .font(.title3.bold())
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ], spacing: 10) {
                ForEach(HealthStatusCategory.defaultCategories) { category in
                    HealthStatusTile(category: category) {
                        if let path = category.webPath {
                            webURL = URL(string: Config.apiBaseURL + path)
                            showWebSheet = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Signals

    private var signalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(hex: "3B82F6"))
                Text("Key Signals")
                    .font(.title3.bold())
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(apiManager.signals.keys.sorted()), id: \.self) { key in
                        if let signal = apiManager.signals[key] {
                            SignalCard(key: key, signal: signal)
                        }
                    }
                }
                .padding(.horizontal)
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

                VitalCard(
                    icon: "heart.circle.fill",
                    title: "Blood Pressure",
                    value: healthKitManager.todayHealth.bloodPressureSystolic > 0
                        ? "\(Int(healthKitManager.todayHealth.bloodPressureSystolic))/\(Int(healthKitManager.todayHealth.bloodPressureDiastolic))"
                        : "--/--",
                    unit: "mmHg",
                    trend: nil,
                    sparkline: healthKitManager.todayHealth.systolicHistory.map { $0.1 },
                    color: Color(hex: "DC2626")
                )

                VitalCard(
                    icon: "drop.fill",
                    title: "Glucose",
                    value: healthKitManager.todayHealth.bloodGlucose > 0
                        ? formatNumber(healthKitManager.todayHealth.bloodGlucose)
                        : "--",
                    unit: "mg/dL",
                    trend: healthKitManager.todayHealth.bloodGlucose > 0
                        ? trendDelta(
                            current: healthKitManager.todayHealth.bloodGlucose,
                            average: healthKitManager.todayHealth.avgBloodGlucose,
                            invertColor: true
                        )
                        : nil,
                    sparkline: healthKitManager.todayHealth.bloodGlucoseHistory.map { $0.1 },
                    color: .orange
                )

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

    // MARK: - Trend Charts

    private var trendChartsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(hex: "3B82F6"))
                Text("Trends")
                    .font(.title3.bold())
            }

            // LDL chart from lab stats
            if let ldlData = apiManager.labStats["LDL-C"] ?? apiManager.labStats["LDL"], ldlData.count >= 2 {
                LabTrendChartView(
                    title: "LDL Cholesterol",
                    data: ldlData,
                    color: .blue,
                    unit: "mg/dL"
                )
            }

            // VAT chart from dashboard signals
            if apiManager.vatChart.count >= 2 {
                TrendChartView(
                    title: "Visceral Fat",
                    data: apiManager.vatChart,
                    color: .orange,
                    unit: "cm²",
                    chartType: .bar
                )
            }

            // Free T from lab stats
            if let ftData = apiManager.labStats["Free T"] ?? apiManager.labStats["Free Testosterone"], ftData.count >= 2 {
                LabTrendChartView(
                    title: "Free Testosterone",
                    data: ftData,
                    color: .purple,
                    unit: "pg/mL"
                )
            }

            // Calcium score
            if apiManager.calcChart.count >= 2 {
                TrendChartView(
                    title: "Coronary Calcium Score",
                    data: apiManager.calcChart,
                    color: .red,
                    unit: "",
                    chartType: .line
                )
            }
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
        if value >= 1000 { return String(format: "%.0f", value) }
        if value == value.rounded() { return String(format: "%.0f", value) }
        return String(format: "%.1f", value)
    }

    private func trendDelta(current: Double, average: Double, invertColor: Bool = false) -> TrendInfo? {
        guard current > 0 && average > 0 else { return nil }
        let delta = current - average
        let pct = (delta / average) * 100
        return TrendInfo(delta: delta, percentage: pct, invertColor: invertColor)
    }

    private func alertColor(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        default: return .orange
        }
    }
}
