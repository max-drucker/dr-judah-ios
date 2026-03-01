import SwiftUI

struct KeyInsightItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let priority: InsightPriority

    enum InsightPriority: String {
        case action = "action"
        case watch = "watch"

        var color: Color {
            switch self {
            case .action: return .red
            case .watch: return Color(red: 0.96, green: 0.76, blue: 0.03)
            }
        }

        var label: String {
            rawValue.uppercased()
        }
    }
}

struct KeyInsightsView: View {
    @EnvironmentObject var apiManager: APIManager
    @State private var expandedId: UUID?

    private var insights: [KeyInsightItem] {
        // Deduplicate by normalized title
        var seen = Set<String>()
        return apiManager.criticalAlerts.compactMap { alert -> KeyInsightItem? in
            let normalizedTitle = alert.title.lowercased().trimmingCharacters(in: .whitespaces)
            guard !seen.contains(normalizedTitle) else { return nil }
            seen.insert(normalizedTitle)

            let isWatch = alert.severityColor == "yellow" || alert.severity?.lowercased() == "low"
            let icon: String = {
                switch alert.severityColor {
                case "red": return "🚨"
                case "orange": return "⚠️"
                default: return "✅"
                }
            }()
            return KeyInsightItem(
                icon: icon,
                title: alert.title,
                detail: alert.message,
                priority: isWatch ? .watch : .action
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
                Text("Key Insights")
                    .font(.title3.bold())
                Spacer()
                Text("\(insights.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            if insights.isEmpty && apiManager.isLoadingDashboard {
                HStack {
                    ProgressView().scaleEffect(0.8)
                    Text("Loading insights…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            } else if insights.isEmpty {
                Text("No critical insights right now — all clear!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 8) {
                    ForEach(insights) { insight in
                        InsightRowCard(
                            insight: insight,
                            isExpanded: expandedId == insight.id,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    expandedId = expandedId == insight.id ? nil : insight.id
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct InsightRowCard: View {
    let insight: KeyInsightItem
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(insight.icon)
                    .font(.title3)

                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(isExpanded ? nil : 1)
                    .foregroundStyle(.primary)

                Spacer(minLength: 4)

                Text(insight.priority.label)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(insight.priority.color))

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(12)

            if isExpanded {
                Text(insight.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.2), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
