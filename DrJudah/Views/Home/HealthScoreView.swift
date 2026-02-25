import SwiftUI

struct HealthScoreView: View {
    let score: Int

    private var scoreColor: Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .drJudahBlue
        case 40..<60: return .orange
        default: return .red
        }
    }

    private var scoreLabel: String {
        switch score {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        default: return "Needs Attention"
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(scoreColor.opacity(0.15), lineWidth: 12)

                // Progress ring
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100.0)
                    .stroke(
                        AngularGradient(
                            colors: [scoreColor.opacity(0.6), scoreColor],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 1.0), value: score)

                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)

                    Text(scoreLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 140, height: 140)

            Text("Health Score")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
