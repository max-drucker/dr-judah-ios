import SwiftUI

struct DataTypeRow: View {
    let icon: String
    let title: String
    var count: Int? = nil
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 28)

            Text(title)

            Spacer()

            if let count {
                Text("\(count) records")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        }
    }
}
