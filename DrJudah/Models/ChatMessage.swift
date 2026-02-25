import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date

    enum Role: String, Codable {
        case user
        case assistant
    }

    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

struct AskJudahRequest: Codable {
    let message: String
    let history: [[String: String]]
    let model: String
    let healthContext: String?
}

struct AskJudahResponse: Codable {
    let response: String
}
