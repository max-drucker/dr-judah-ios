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

    static let hardcoded: [KeyInsightItem] = [
        KeyInsightItem(
            icon: "🚨",
            title: "Muscle loss crisis — ALM Index 7.25 (7th percentile)",
            detail: "Appendicular lean mass is critically low, placing you in clinical sarcopenia territory. Immediate intervention needed: TRT evaluation, progressive resistance training 3-4x/week, and minimum 150g protein daily. Creatine monohydrate 5g/day recommended as well.",
            priority: .action
        ),
        KeyInsightItem(
            icon: "🚨",
            title: "RHR 91 bpm + HRV 23ms = sympathetic overdrive",
            detail: "Your autonomic nervous system is stuck in fight-or-flight. This combination correlates with elevated cardiovascular risk and poor recovery. Needs cardiology evaluation to rule out underlying causes. Consider beta-blocker if lifestyle optimization doesn't improve within 4-6 weeks.",
            priority: .action
        ),
        KeyInsightItem(
            icon: "💊",
            title: "Diastolic BP 89 on Ramipril 2.5mg — right drug, wrong dose",
            detail: "Borderline Stage 1 hypertension despite current ACE inhibitor therapy. Ramipril is the right choice for cardiac protection, but 2.5mg is the starting dose. Standard titration would be to 5mg. Discuss at next PCP visit. Monitor for cough or dizziness.",
            priority: .action
        ),
        KeyInsightItem(
            icon: "✅",
            title: "CGM avg 96, 99% in range — elite metabolic control",
            detail: "Average glucose 96 mg/dL with 99% time in range (70-140). HbA1c 5.2% confirms excellent long-term control. However, your TCF7L2 TT genotype means elevated lifetime diabetes risk — never stop monitoring. Continue CGM and low-glycemic habits.",
            priority: .watch
        ),
        KeyInsightItem(
            icon: "🧬",
            title: "DNA flagged 3 supplement gaps: retinol, lutein, collagen",
            detail: "Genetic variants identified: BCMO1 (poor beta-carotene → retinol conversion, supplement preformed vitamin A), CFH (macular degeneration risk, supplement lutein + zeaxanthin), COL5A1 (collagen integrity, supplement hydrolyzed collagen peptides 10g/day).",
            priority: .action
        ),
    ]
}

struct KeyInsightsView: View {
    @State private var expandedId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
                Text("Key Insights")
                    .font(.title3.bold())
            }
            .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(KeyInsightItem.hardcoded) { insight in
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

struct InsightRowCard: View {
    let insight: KeyInsightItem
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed row
            HStack(spacing: 10) {
                Text(insight.icon)
                    .font(.title3)

                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(isExpanded ? nil : 1)
                    .foregroundStyle(.primary)

                Spacer(minLength: 4)

                // Priority badge
                Text(insight.priority.label)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(insight.priority.color)
                    )

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(12)

            // Expanded detail
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
