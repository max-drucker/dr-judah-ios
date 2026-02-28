import SwiftUI
import Charts

struct TrendsView: View {
    @EnvironmentObject var apiManager: APIManager

    @State private var selectedPeriod = "30d"

    private let periods: [(label: String, value: String)] = [
        ("30 Days", "30d"),
        ("90 Days", "90d"),
        ("1 Year", "1y"),
        ("All Time", "all")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    periodSelector

                    if apiManager.isLoadingTrends && apiManager.trends == nil {
                        ProgressView("Loading trends…")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let trends = apiManager.trends {
                        cardiovascularSection(trends.cardio)
                        metabolicSection(trends.metabolic)
                        sleepSection(trends.sleep)
                        fitnessSection(trends.fitness)
                        correlationsSection(trends.correlations)
                    } else if let error = apiManager.trendsError {
                        Text(error)
                            .foregroundStyle(.red)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Trends")
            .refreshable {
                await apiManager.fetchTrends(period: selectedPeriod, force: true)
            }
        }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        HStack(spacing: 8) {
            ForEach(periods, id: \.value) { period in
                Button {
                    selectedPeriod = period.value
                    Task {
                        await apiManager.fetchTrends(period: period.value, force: true)
                    }
                } label: {
                    Text(period.label)
                        .font(.caption.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedPeriod == period.value ? Color.blue : Color.clear)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.blue, lineWidth: selectedPeriod == period.value ? 0 : 1.5)
                        )
                        .foregroundStyle(selectedPeriod == period.value ? .white : .blue)
                }
            }
        }
    }

    // MARK: - Cardiovascular

    @ViewBuilder
    private func cardiovascularSection(_ cardio: TrendsCardio?) -> some View {
        sectionCard("Cardiovascular", icon: "heart.fill") {
            if let rhr = cardio?.rhr, rhr.count >= 2 {
                trendLineChart("Resting Heart Rate", data: rhr, color: .orange, unit: "bpm")
            }
            if let hrv = cardio?.hrv, hrv.count >= 2 {
                trendLineChart("HRV", data: hrv, color: .purple, unit: "ms")
            }
            if let bp = cardio?.bp, bp.count >= 2 {
                bpChart(bp)
            }
        }
    }

    // MARK: - Metabolic

    @ViewBuilder
    private func metabolicSection(_ metabolic: TrendsMetabolic?) -> some View {
        sectionCard("Metabolic", icon: "flame.fill") {
            if let glucose = metabolic?.glucose, glucose.count >= 2 {
                glucoseChart(glucose)
            }
            if let weight = metabolic?.weight, weight.count >= 2 {
                trendLineChart("Weight", data: weight, color: .blue, unit: "lbs")
            }
            if let cal = metabolic?.activeCalories, cal.count >= 2 {
                trendBarChart("Active Calories", data: cal, color: .orange, unit: "kcal")
            }
        }
    }

    // MARK: - Sleep

    @ViewBuilder
    private func sleepSection(_ sleep: TrendsSleep?) -> some View {
        sectionCard("Sleep", icon: "moon.fill") {
            if let nights = sleep?.byNight, nights.count >= 2 {
                sleepDurationChart(nights)
                sleepStagesChart(nights)
            } else {
                noDataPlaceholder()
            }
        }
    }

    // MARK: - Fitness

    @ViewBuilder
    private func fitnessSection(_ fitness: TrendsFitness?) -> some View {
        sectionCard("Fitness", icon: "figure.run") {
            if let steps = fitness?.steps, steps.count >= 2 {
                trendBarChart("Steps", data: steps, color: .teal, unit: "steps")
            }
            if let ex = fitness?.exerciseMinutes, ex.count >= 2 {
                trendBarChart("Exercise Minutes", data: ex, color: .green, unit: "min")
            }
            if let vo2 = fitness?.vo2Max, vo2.count >= 2 {
                trendLineChart("VO₂ Max", data: vo2, color: .red, unit: "")
            }
        }
    }

    // MARK: - Correlations

    @ViewBuilder
    private func correlationsSection(_ correlations: TrendsCorrelations?) -> some View {
        let all: [TrendsCorrelation] = [
            correlations?.hrvVsSleep,
            correlations?.rhrVsExercise,
            correlations?.sleepVsRhr
        ].compactMap { $0 }.filter { $0.data.count >= 3 }

        if !all.isEmpty {
            sectionCard("Correlations", icon: "point.3.connected.trianglepath.dotted") {
                ForEach(all) { corr in
                    correlationChart(corr)
                }
            }
        }
    }

    // MARK: - Chart Builders

    private func trendLineChart(_ title: String, data: [TrendsDateValue], color: Color, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            chartHeader(title, value: data.last.map { "\(String(format: "%.0f", $0.value)) \(unit)" })
            Chart(data) { point in
                LineMark(x: .value("Date", point.parsedDate), y: .value("Value", point.value))
                    .foregroundStyle(color.gradient)
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("Date", point.parsedDate), y: .value("Value", point.value))
                    .foregroundStyle(color.opacity(0.1).gradient)
                    .interpolationMethod(.catmullRom)
            }
            .frame(height: 150)
            .chartXAxis { dateAxis }
            .chartYAxis { valueAxis }
        }
    }

    private func trendBarChart(_ title: String, data: [TrendsDateValue], color: Color, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            chartHeader(title, value: data.last.map { "\(String(format: "%.0f", $0.value)) \(unit)" })
            Chart(data) { point in
                BarMark(x: .value("Date", point.parsedDate), y: .value("Value", point.value))
                    .foregroundStyle(color.gradient)
                    .cornerRadius(4)
            }
            .frame(height: 150)
            .chartXAxis { dateAxis }
            .chartYAxis { valueAxis }
        }
    }

    private func bpChart(_ data: [TrendsBP]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            chartHeader("Blood Pressure", value: data.last.map { "\(Int(round($0.systolic)))/\(Int(round($0.diastolic)))" })
            Chart(data) { point in
                LineMark(x: .value("Date", point.parsedDate), y: .value("Systolic", point.systolic), series: .value("Type", "Systolic"))
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Date", point.parsedDate), y: .value("Diastolic", point.diastolic), series: .value("Type", "Diastolic"))
                    .foregroundStyle(.orange)
                    .interpolationMethod(.catmullRom)
            }
            .frame(height: 150)
            .chartXAxis { dateAxis }
            .chartYAxis { valueAxis }
            .chartForegroundStyleScale(["Systolic": Color.blue, "Diastolic": Color.orange])
        }
    }

    private func glucoseChart(_ data: [TrendsGlucose]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            chartHeader("Glucose", value: data.last.map { "\(String(format: "%.0f", $0.avg)) mg/dL" })
            Chart(data) { point in
                AreaMark(x: .value("Date", point.parsedDate), yStart: .value("Min", point.min), yEnd: .value("Max", point.max))
                    .foregroundStyle(.green.opacity(0.15))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Date", point.parsedDate), y: .value("Avg", point.avg))
                    .foregroundStyle(.green)
                    .interpolationMethod(.catmullRom)
            }
            .frame(height: 150)
            .chartXAxis { dateAxis }
            .chartYAxis { valueAxis }
        }
    }

    private func sleepDurationChart(_ nights: [TrendsSleepNight]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            chartHeader("Total Sleep", value: nights.last.map { "\(String(format: "%.1f", $0.total)) hrs" })
            Chart(nights) { night in
                LineMark(x: .value("Date", night.parsedDate), y: .value("Hours", night.total))
                    .foregroundStyle(.indigo.gradient)
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("Date", night.parsedDate), y: .value("Hours", night.total))
                    .foregroundStyle(.indigo.opacity(0.1).gradient)
                    .interpolationMethod(.catmullRom)
            }
            .frame(height: 150)
            .chartXAxis { dateAxis }
            .chartYAxis { valueAxis }
        }
    }

    private func sleepStagesChart(_ nights: [TrendsSleepNight]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            chartHeader("Sleep Stages", value: nil)
            Chart(nights) { night in
                BarMark(x: .value("Date", night.parsedDate), y: .value("Hours", night.deep ?? 0))
                    .foregroundStyle(by: .value("Stage", "Deep"))
                BarMark(x: .value("Date", night.parsedDate), y: .value("Hours", night.rem ?? 0))
                    .foregroundStyle(by: .value("Stage", "REM"))
                BarMark(x: .value("Date", night.parsedDate), y: .value("Hours", night.core ?? 0))
                    .foregroundStyle(by: .value("Stage", "Core"))
            }
            .chartForegroundStyleScale(["Deep": Color(red: 0.1, green: 0.1, blue: 0.5), "REM": Color.purple, "Core": Color(red: 0.5, green: 0.7, blue: 1.0)])
            .frame(height: 150)
            .chartXAxis { dateAxis }
            .chartYAxis { valueAxis }
        }
    }

    private func correlationChart(_ corr: TrendsCorrelation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(corr.label)
                    .font(.subheadline.bold())
                Spacer()
                Text("r = \(String(format: "%.2f", corr.r))")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(correlationColor(corr.r).opacity(0.2))
                    )
                    .foregroundStyle(correlationColor(corr.r))
            }
            Chart(corr.data) { point in
                PointMark(x: .value(corr.xLabel, point.x), y: .value(corr.yLabel, point.y))
                    .symbolSize(40)
                    .foregroundStyle(.purple.opacity(0.6))
            }
            .frame(height: 160)
            .chartXAxisLabel(corr.xLabel, position: .bottom)
            .chartYAxisLabel(corr.yLabel, position: .leading)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    AxisValueLabel().font(.caption2)
                }
            }
            .chartYAxis { valueAxis }
        }
    }

    // MARK: - Helpers

    private func sectionCard<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.headline)
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func chartHeader(_ title: String, value: String?) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.bold())
            Spacer()
            if let value {
                Text(value)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dateAxis: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
            AxisValueLabel().font(.caption2)
        }
    }

    private var valueAxis: some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
            AxisValueLabel().font(.caption2)
        }
    }

    private func correlationColor(_ r: Double) -> Color {
        let absR = abs(r)
        if absR > 0.5 { return .green }
        if absR > 0.3 { return .orange }
        return .gray
    }

    private func noDataPlaceholder() -> some View {
        Text("Not enough data")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(height: 140)
            .frame(maxWidth: .infinity)
    }
}
