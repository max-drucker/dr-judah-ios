import Foundation
import Supabase
import Combine

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: AppUser?
    @Published var isLoading = false
    @Published var error: String?
    @Published var magicLinkSent = false

    private var client: SupabaseClient { SupabaseManager.shared.client }

    init() {
        Task { await checkSession() }
    }

    func checkSession() async {
        do {
            let session = try await client.auth.session
            isAuthenticated = true
            currentUser = AppUser(
                id: session.user.id,
                email: session.user.email ?? "",
                displayName: session.user.userMetadata["display_name"]?.value as? String,
                createdAt: nil
            )
        } catch {
            isAuthenticated = false
            currentUser = nil
        }
    }

    func signIn(email: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await client.auth.signInWithOTP(
                email: email,
                redirectTo: URL(string: "\(Config.deepLinkScheme)://auth/callback")
            )
            magicLinkSent = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    func handleDeepLink(url: URL) {
        guard url.scheme == Config.deepLinkScheme else { return }

        Task {
            do {
                let session = try await client.auth.session(from: url)
                isAuthenticated = true
                currentUser = AppUser(
                    id: session.user.id,
                    email: session.user.email ?? "",
                    displayName: session.user.userMetadata["display_name"]?.value as? String,
                    createdAt: nil
                )
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {}
        isAuthenticated = false
        currentUser = nil
    }
}
