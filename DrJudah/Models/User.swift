import Foundation

struct AppUser: Identifiable, Codable {
    let id: UUID
    let email: String
    let displayName: String?
    let createdAt: Date?

    var firstName: String {
        displayName?.components(separatedBy: " ").first ?? "there"
    }
}
