import SwiftUI

struct GradientHeader: View {
    let greeting: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .padding(.top, 8)
        .background(Color.drJudahGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }
}
