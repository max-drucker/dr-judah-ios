import Foundation
import Combine

/// Auth is disabled. This manager provides a hardcoded user.
@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = true
    @Published var currentUser: AppUser?

    init() {
        currentUser = AppUser(
            id: UUID(uuidString: Config.userId)!,
            email: Config.userEmail,
            displayName: Config.userName,
            createdAt: nil
        )
    }
}
