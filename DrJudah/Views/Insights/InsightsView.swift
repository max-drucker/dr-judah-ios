import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var apiManager: APIManager
    @State private var dismissedAlerts: Set<String> = {
        Set(UserDefaults.standard.stringArray(forKey: "dismissedAlerts") ?? [])
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    insightsHeader

                    // API Critical Alerts (if any, merged with hardcoded)
                    if !apiManager.criticalAlerts.isEmpty {
                        apiAlertsSection
                            .padding(.horizontal)
                    }

                    // Key Insights
                    keyInsightsSection
                        .padding(.horizontal)

                    // Recommendations
                    recommendationsSection
                        .padding(.horizontal)

                    // Overdue Screenings
                    if !activeScreenings.isEmpty {
                        screeningsSection
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .refreshable {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                apiManager.invalidateCache()
                await apiManager.fetchDashboardSignals(force: true)
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Header

    private var insightsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                Text("Your Health Insights")
                    .font(.title2.bold())
            }

            Text("Curated insights and actionable recommendations based on your complete health data.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - API Alerts

    private var apiAlertsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(.red)
                Text("Live Alerts")
                    .font(.headline)
            }

            ForEach(apiManager.criticalAlerts) { alert in
                AlertInsightCard(alert: alert)
            }
        }
    }

    // MARK: - Key Insights

    private var keyInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color(hex: "3B82F6"))
                Text("Key Insights")
                    .font(.headline)
            }

            ForEach(KeyInsight.allInsights) { insight in
                InsightCard(insight: insight)
            }
        }
    }

    // MARK: - Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("Recommendations")
                    .font(.headline)
            }

            ForEach(AppRecommendation.allRecommendations) { rec in
                RecommendationCard(recommendation: rec)
            }
        }
    }

    // MARK: - Overdue Screenings

    private var activeScreenings: [OverdueScreening] {
        apiManager.overdueScreenings.filter { !dismissedAlerts.contains($0.name) }
    }

    private var screeningsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundStyle(.orange)
                Text("Overdue Screenings")
                    .font(.headline)
            }

            ForEach(activeScreenings) { screening in
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.orange)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(screening.name)
                            .font(.subheadline.bold())

                        if let due = screening.dueDate {
                            Text("Due: \(due)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let last = screening.lastDate {
                            Text("Last: \(last)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    Button {
                        withAnimation {
                            dismissedAlerts.insert(screening.name)
                            UserDefaults.standard.set(Array(dismissedAlerts), forKey: "dismissedAlerts")
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        }
    }
}

// MARK: - Alert Insight Card

struct AlertInsightCard: View {
    let alert: CriticalAlert
    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme

    private var severityColor: Color {
        switch alert.severity?.lowercased() {
        case "critical", "high": return .red
        case "warning", "medium": return .orange
        default: return .yellow
        }
    }

    private var emoji: String {
        switch alert.severity?.lowercased() {
        case "critical", "high": return "🚨"
        case "warning", "medium": return "⚠️"
        default: return "💡"
        }
    }

    private var cardBackground: some ShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(Color(.secondarySystemGroupedBackground))
        } else {
            switch alert.severity?.lowercased() {
            case "critical", "high": return AnyShapeStyle(LinearGradient(colors: [Color(hex: "FEF2F2"), Color(hex: "FEE2E2")], startPoint: .topLeading, endPoint: .bottomTrailing))
            case "warning", "medium": return AnyShapeStyle(LinearGradient(colors: [Color(hex: "FFFBEB"), Color(hex: "FEF3C7")], startPoint: .topLeading, endPoint: .bottomTrailing))
            default: return AnyShapeStyle(LinearGradient(colors: [Color(hex: "F0FDF4"), Color(hex: "DCFCE7")], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }
    }

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text(emoji)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)

                        Text("ACTION")
                            .font(.caption2.bold())
                            .foregroundStyle(severityColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(severityColor.opacity(0.15))
                            )
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

                if isExpanded {
                    Text(alert.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(severityColor.opacity(colorScheme == .dark ? 0.4 : 0.2), lineWidth: colorScheme == .dark ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
