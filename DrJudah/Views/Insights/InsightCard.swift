import SwiftUI

struct InsightCard: View {
    let insight: KeyInsight
    @State private var isExpanded = false

    private var severityColor: Color {
        switch insight.severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .green
        }
    }

    private var backgroundGradient: [Color] {
        switch insight.severity {
        case .critical: return [Color(hex: "FEF2F2"), Color(hex: "FEE2E2")]
        case .warning: return [Color(hex: "FFFBEB"), Color(hex: "FEF3C7")]
        case .info: return [Color(hex: "F0FDF4"), Color(hex: "DCFCE7")]
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
                HStack(spacing: 10) {
                    Text(insight.emoji)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(insight.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)

                        Text(insight.actionType)
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
                    Text(insight.detail)
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
                    .fill(
                        LinearGradient(
                            colors: backgroundGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(severityColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
