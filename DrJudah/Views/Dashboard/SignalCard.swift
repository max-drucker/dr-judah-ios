import SwiftUI

struct SignalCard: View {
    let key: String
    let signal: Signal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(signal.emoji ?? "📊")
                    .font(.title3)
                Text(signal.label)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                if let value = signal.value {
                    Text(formatSignalValue(value))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.7)
                } else {
                    Text("--")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                if let unit = signal.unit, !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Trend + delta
            if let delta = signal.delta {
                HStack(spacing: 4) {
                    Text(signal.trendArrow)
                        .font(.caption.bold())
                        .foregroundStyle(trendColor(for: signal))

                    Text(formatDelta(delta))
                        .font(.caption)
                        .foregroundStyle(trendColor(for: signal))

                    if let prev = signal.previous {
                        Text("from \(formatSignalValue(prev))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if let insight = signal.insight, !insight.isEmpty {
                Text(insight)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(width: 170, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
        )
    }

    private func formatSignalValue(_ value: Double) -> String {
        if value == value.rounded() && value < 10000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func formatDelta(_ delta: Double) -> String {
        let sign = delta > 0 ? "+" : ""
        if abs(delta) == abs(delta.rounded()) {
            return "\(sign)\(String(format: "%.0f", delta))"
        }
        return "\(sign)\(String(format: "%.1f", delta))"
    }

    private func trendColor(for signal: Signal) -> Color {
        switch signal.statusColor {
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        default: return .secondary
        }
    }
}
