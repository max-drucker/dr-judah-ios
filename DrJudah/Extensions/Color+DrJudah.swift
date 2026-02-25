import SwiftUI

extension Color {
    static let drJudahBlue = Color(hex: "2563EB")
    static let drJudahIndigo = Color(hex: "4338CA")

    static let drJudahGradient = LinearGradient(
        colors: [.drJudahBlue, .drJudahIndigo],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
