import SwiftUI

struct VitalCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let trend: TrendInfo?
    let sparkline: [Double]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let trend {
                    Text(trend.text)
                        .font(.caption2.bold())
                        .foregroundStyle(trend.color)
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.7)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Mini sparkline
            if sparkline.count >= 2 {
                SparklineView(data: sparkline, color: color)
                    .frame(height: 24)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct SparklineView: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let minVal = data.min() ?? 0
            let maxVal = data.max() ?? 1
            let range = max(maxVal - minVal, 1)

            Path { path in
                for (index, value) in data.enumerated() {
                    let x = geo.size.width * CGFloat(index) / CGFloat(data.count - 1)
                    let y = geo.size.height * (1 - CGFloat((value - minVal) / range))
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}
