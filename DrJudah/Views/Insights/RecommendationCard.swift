import SwiftUI

struct RecommendationCard: View {
    let recommendation: AppRecommendation

    private var priorityColor: Color {
        switch recommendation.priority {
        case .high: return .red
        case .medium: return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: recommendation.icon)
                    .font(.title3)
                    .foregroundStyle(priorityColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.subheadline.bold())

                    HStack(spacing: 6) {
                        Text(recommendation.priority.rawValue)
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(priorityColor))

                        Text(recommendation.category)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .stroke(Color(.separator), lineWidth: 0.5)
                            )
                    }
                }

                Spacer()
            }

            Text(recommendation.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Action buttons
            if recommendation.actionURL != nil || recommendation.contactInfo != nil {
                HStack(spacing: 10) {
                    if let urlString = recommendation.actionURL, let url = URL(string: urlString) {
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                Image(systemName: "cart.fill")
                                    .font(.caption2)
                                Text("Amazon")
                                    .font(.caption.bold())
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color(hex: "FF9900")))
                        }
                    }

                    if let contact = recommendation.contactInfo {
                        HStack(spacing: 4) {
                            Image(systemName: "phone.fill")
                                .font(.caption2)
                            Text(contact)
                                .font(.caption)
                        }
                        .foregroundStyle(Color(hex: "3B82F6"))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
        )
    }
}
