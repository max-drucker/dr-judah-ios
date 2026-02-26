import SwiftUI

struct HealthStatusTile: View {
    let category: HealthStatusCategory
    let onTap: () -> Void

    private var statusColor: Color {
        switch category.status {
        case .green: return .green
        case .yellow: return .yellow
        case .orange: return .orange
        case .red: return .red
        case .gray: return .gray
        }
    }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: category.icon)
                        .font(.title3)
                        .foregroundStyle(statusColor)

                    Spacer()

                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                        .shadow(color: statusColor.opacity(0.5), radius: 3)
                }

                Text(category.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Text(category.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(statusColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
