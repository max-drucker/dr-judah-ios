import SwiftUI

struct AskJudahView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty {
                                emptyState
                                    .padding(.top, 60)
                            }

                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            if isLoading {
                                HStack {
                                    TypingIndicator()
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .id("loading")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) {
                        withAnimation {
                            proxy.scrollTo(messages.last?.id.uuidString ?? "loading", anchor: .bottom)
                        }
                    }
                }

                Divider()

                // Input
                HStack(spacing: 12) {
                    TextField("Ask Dr. Judah anything…", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .focused($inputFocused)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(inputText.isEmpty ? .gray : Color.drJudahBlue)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
            }
            .navigationTitle("Ask Judah")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        messages.removeAll()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .disabled(messages.isEmpty)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(Color.drJudahGradient)

            Text("Ask Dr. Judah")
                .font(.title2.bold())

            Text("Get personalized health insights based on your Apple Health data.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 8) {
                SuggestionChip("How's my recovery today?")
                SuggestionChip("Analyze my sleep trends")
                SuggestionChip("Should I do a hard workout?")
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func SuggestionChip(_ text: String) -> some View {
        Button {
            inputText = text
            sendMessage()
        } label: {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.drJudahBlue.opacity(0.3), lineWidth: 1)
                )
                .foregroundStyle(.primary)
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""
        isLoading = true

        Task {
            let health = healthKitManager.todayHealth
            let context = "iOS app context — Today: Steps: \(Int(health.steps)), Resting HR: \(Int(health.restingHeartRate)) bpm, HRV: \(Int(health.hrv)) ms, Active Cal: \(Int(health.activeCalories)), Exercise: \(Int(health.exerciseMinutes)) min, Health Score: \(healthKitManager.healthScore)/100"

            do {
                let response = try await SupabaseManager.shared.askJudah(
                    message: text,
                    history: messages,
                    healthContext: context
                )
                let assistantMessage = ChatMessage(role: .assistant, content: response)
                messages.append(assistantMessage)
            } catch {
                let errorMessage = ChatMessage(role: .assistant, content: "Sorry, I couldn't connect. Please try again.")
                messages.append(errorMessage)
            }

            isLoading = false
        }
    }
}

struct TypingIndicator: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 6, height: 6)
                    .opacity(phase == Double(i) ? 1 : 0.3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                phase = 2
            }
        }
    }
}
