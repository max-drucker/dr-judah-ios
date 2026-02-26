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
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.title)
                            .font(.subheadline.bold())
                        Text(alert.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.red.opacity(0.08))
                )
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
