import SwiftUI
import Charts

struct SleepView: View {
    @EnvironmentObject var apiManager: APIManager

    @State private var sleepData: [TrendsSleepNight] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("Loading sleep data…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if sleepData.isEmpty {
                    emptyState
                } else {
                    lastNightSummary
                    durationChart
                    stagesChart
                    efficiencyChart
                }

                Spacer(minHeight: 40)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Sleep Analysis")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadSleepData() }
        .refreshable { await loadSleepData(force: true) }
    }

    // MARK: - Load Data

    private func loadSleepData(force: Bool = false) async {
        isLoading = true
        await apiManager.fetchTrends(period: "30d", force: force)
        if let nights = apiManager.trends?.sleep {
            sleepData = nights.sorted { $0.parsedDate < $1.parsedDate }
        }
        isLoading = false
    }

    // MARK: - Last Night Summary

    private var lastNightSummary: some View {
        let last = sleepData.last
        return VStack(spacing: 16) {
            HStack {
                Image(systemName: "moon.stars.fill")
                    .font(.title2)
                    .foregroundStyle(.indigo)
                Text("Last Night")
                    .font(.title2.bold())
                Spacer()
                if let last {
                    Text(last.parsedDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let last {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    sleepMetric("Total", value: String(format: "%.1f", last.total), unit: "hrs", color: .indigo)
                    sleepMetric("Deep", value: last.deep.map { String(format: "%.1f", $0) } ?? "--", unit: "hrs", color: Color(red: 0.1, green: 0.1, blue: 0.5))
                    sleepMetric("REM", value: last.rem.map { String(format: "%.1f", $0) } ?? "--", unit: "hrs", color: .purple)
                    sleepMetric("Core", value: last.core.map { String(format: "%.1f", $0) } ?? "--", unit: "hrs", color: Color(red: 0.5, green: 0.7, blue: 1.0))
                    sleepMetric("Awake", value: last.awake.map { String(format: "%.1f", $0) } ?? "--", unit: "hrs", color: .orange)
                    sleepMetric("Efficiency", value: last.efficiency.map { String(format: "%.0f", $0) } ?? "--", unit: "%", color: .teal)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemBackground)))
    }

    private func sleepMetric(_ title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(color)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.08)))
    }

    // MARK: - Duration Chart

    private var durationChart: some View {
        chartCard("Sleep Duration", icon: "clock.fill") {
            Chart(sleepData) { night in
                LineMark(x: .value("Date", night.parsedDate), y: .value("Hours", night.total))
                    .foregroundStyle(.indigo.gradient)
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("Date", night.parsedDate), y: .value("Hours", night.total))
                    .foregroundStyle(.indigo.opacity(0.1).gradient)
                    .interpolationMethod(.catmullRom)
            }
            .frame(height: 180)
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)); AxisValueLabel().font(.caption2) } }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)); AxisValueLabel().font(.caption2) } }

            let avg = sleepData.reduce(0) { $0 + $1.total } / Double(sleepData.count)
            Text("30-day avg: \(String(format: "%.1f", avg)) hrs")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    // MARK: - Stages Chart

    private var stagesChart: some View {
        chartCard("Sleep Stages", icon: "chart.bar.fill") {
            Chart(sleepData) { night in
                BarMark(x: .value("Date", night.parsedDate), y: .value("Hours", night.deep ?? 0))
                    .foregroundStyle(by: .value("Stage", "Deep"))
                BarMark(x: .value("Date", night.parsedDate), y: .value("Hours", night.rem ?? 0))
                    .foregroundStyle(by: .value("Stage", "REM"))
                BarMark(x: .value("Date", night.parsedDate), y: .value("Hours", night.core ?? 0))
                    .foregroundStyle(by: .value("Stage", "Core"))
            }
            .chartForegroundStyleScale(["Deep": Color(red: 0.1, green: 0.1, blue: 0.5), "REM": Color.purple, "Core": Color(red: 0.5, green: 0.7, blue: 1.0)])
            .frame(height: 180)
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)); AxisValueLabel().font(.caption2) } }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)); AxisValueLabel().font(.caption2) } }
        }
    }

    // MARK: - Efficiency Chart

    private var efficiencyChart: some View {
        let withEff = sleepData.filter { $0.efficiency != nil }
        return Group {
            if withEff.count >= 2 {
                chartCard("Sleep Efficiency", icon: "gauge.with.dots.needle.67percent") {
                    Chart(withEff) { night in
                        LineMark(x: .value("Date", night.parsedDate), y: .value("Efficiency", night.efficiency ?? 0))
                            .foregroundStyle(.teal.gradient)
                            .interpolationMethod(.catmullRom)
                        AreaMark(x: .value("Date", night.parsedDate), y: .value("Efficiency", night.efficiency ?? 0))
                            .foregroundStyle(.teal.opacity(0.1).gradient)
                            .interpolationMethod(.catmullRom)
                    }
                    .frame(height: 150)
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)); AxisValueLabel().font(.caption2) } }
                    .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)); AxisValueLabel().font(.caption2) } }
                }
            }
        }
    }

    // MARK: - Helpers

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bed.double.fill")
                .font(.system(size: 48))
                .foregroundStyle(.indigo)
            Text("No Sleep Data")
                .font(.title2.bold())
            Text("Sleep data from Apple Health will appear here after your next HealthKit sync.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 40)
    }

    private func chartCard<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
            content()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemBackground)))
    }
}
