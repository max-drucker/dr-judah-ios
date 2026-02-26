import SwiftUI
import Charts

struct TrendChartView: View {
    let title: String
    let data: [ChartDataPoint]
    let color: Color
    let unit: String
    let chartType: ChartType

    enum ChartType {
        case line
        case bar
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.subheadline.bold())
                Spacer()
                if let last = data.last {
                    Text("\(String(format: "%.0f", last.value)) \(unit)")
                        .font(.caption.bold())
                        .foregroundStyle(color)
                }
            }

            if data.count >= 2 {
                Chart {
                    ForEach(data) { point in
                        switch chartType {
                        case .line:
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(color.gradient)
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("Date", point.date),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(color.opacity(0.1).gradient)
                            .interpolationMethod(.catmullRom)

                        case .bar:
                            BarMark(
                                x: .value("Date", point.date),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(color.gradient)
                            .cornerRadius(4)
                        }
                    }
                }
                .frame(height: 140)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
            } else {
                Text("Not enough data")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Lab-based trend chart using LabDataPoint

struct LabTrendChartView: View {
    let title: String
    let data: [LabDataPoint]
    let color: Color
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.subheadline.bold())
                Spacer()
                if let last = data.last {
                    Text("\(String(format: "%.0f", last.value)) \(unit)")
                        .font(.caption.bold())
                        .foregroundStyle(color)
                }
            }

            if data.count >= 2 {
                Chart {
                    ForEach(data) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(color.gradient)
                        .interpolationMethod(.catmullRom)
                        .symbol(.circle)
                        .symbolSize(30)

                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(color.opacity(0.08).gradient)
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 140)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
            } else {
                Text("Not enough data")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
