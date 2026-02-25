import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @FocusState private var emailFocused: Bool

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.drJudahGradient)
                            .frame(width: 100, height: 100)

                        Image(systemName: "sparkles")
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: .drJudahBlue.opacity(0.3), radius: 20, y: 10)

                    Text("Dr. Judah")
                        .font(.system(size: 36, weight: .bold, design: .rounded))

                    Text("Your Personal Health Intelligence")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if authManager.magicLinkSent {
                    // Success state
                    VStack(spacing: 16) {
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.drJudahGradient)

                        Text("Check your email!")
                            .font(.title2.bold())

                        Text("We sent a magic link to\n\(email)")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)

                        Button("Use a different email") {
                            authManager.magicLinkSent = false
                        }
                        .font(.footnote)
                        .padding(.top, 8)
                    }
                    .transition(.opacity.combined(with: .scale))
                } else {
                    // Login form
                    VStack(spacing: 16) {
                        TextField("Email address", text: $email)
                            .textFieldStyle(.plain)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($emailFocused)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(.secondarySystemBackground))
                            )

                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            Task { await authManager.signIn(email: email) }
                        } label: {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Send Magic Link")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.drJudahGradient)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(email.isEmpty || authManager.isLoading)
                        .opacity(email.isEmpty ? 0.6 : 1)

                        if let error = authManager.error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                Text("Powered by Apple Health & AI")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .padding(.bottom, 8)
            }
        }
        .animation(.spring(duration: 0.4), value: authManager.magicLinkSent)
    }
}
