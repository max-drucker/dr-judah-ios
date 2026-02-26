import SwiftUI

struct AskJudahView: View {
    @State private var conversations: [Conversation] = []
    @State private var activeConversationId: String?
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var isLoadingConversations = false
    @State private var showHistory = false
    @FocusState private var inputFocused: Bool

    private var activeConversation: Conversation? {
        conversations.first { $0.id == activeConversationId }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty && !isLoading {
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
                            if let lastMessage = messages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showHistory.toggle()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.body)
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        startNewConversation()
                    } label: {
                        Image(systemName: "plus.bubble")
                            .font(.body)
                    }

                    Button {
                        messages.removeAll()
                        activeConversationId = nil
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .disabled(messages.isEmpty)
                }
            }
            .sheet(isPresented: $showHistory) {
                conversationHistorySheet
            }
            .task {
                await loadConversations()
            }
        }
    }

    // MARK: - Conversation History Sheet

    private var conversationHistorySheet: some View {
        NavigationStack {
            Group {
                if isLoadingConversations {
                    ProgressView("Loading conversations…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if conversations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No conversations yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(conversations, id: \.id) { conv in
                            Button {
                                loadConversation(conv)
                                showHistory = false
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(conv.title)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)

                                    HStack {
                                        Text("\(conv.messages.count) messages")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Spacer()

                                        Text(formatRelativeDate(conv.updatedAt))
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showHistory = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(Color.drJudahGradient)

            Text("Ask Dr. Judah")
                .font(.title2.bold())

            Text("Get personalized health insights based on your complete health profile — labs, genetics, imaging, supplements, Apple Health, and more.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 8) {
                SuggestionChip("How's my recovery today?")
                SuggestionChip("Analyze my recent bloodwork")
                SuggestionChip("What should I focus on this week?")
                SuggestionChip("Review my supplement stack")
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

    // MARK: - Networking

    private func loadConversations() async {
        isLoadingConversations = true
        defer { isLoadingConversations = false }

        guard let url = URL(string: "\(Config.apiBaseURL)/api/conversations") else { return }
        var request = URLRequest(url: url)
        request.setValue(Config.userEmail, forHTTPHeaderField: "X-User-Email")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode([Conversation].self, from: data)
            conversations = decoded
        } catch {
            print("Failed to load conversations: \(error)")
        }
    }

    private func loadConversation(_ conv: Conversation) {
        activeConversationId = conv.id
        messages = conv.messages.map { msg in
            ChatMessage(
                role: msg.role == "user" ? .user : .assistant,
                content: msg.content
            )
        }
    }

    private func saveConversation() async {
        let msgDicts = messages.map { ["role": $0.role.rawValue, "content": $0.content] }

        let title: String
        if let first = messages.first(where: { $0.role == .user }) {
            title = String(first.content.prefix(50))
        } else {
            title = "New conversation"
        }

        if let existingId = activeConversationId {
            // Update
            let body: [String: Any] = [
                "id": existingId,
                "messages": msgDicts,
                "title": title,
            ]
            guard let url = URL(string: "\(Config.apiBaseURL)/api/conversations") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(Config.userEmail, forHTTPHeaderField: "X-User-Email")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: request)
        } else {
            // Create
            let body: [String: Any] = [
                "title": title,
                "messages": msgDicts,
                "model": "anthropic/claude-sonnet-4",
            ]
            guard let url = URL(string: "\(Config.apiBaseURL)/api/conversations") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(Config.userEmail, forHTTPHeaderField: "X-User-Email")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            if let (data, _) = try? await URLSession.shared.data(for: request),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let id = json["id"] as? String {
                activeConversationId = id
            }
        }
    }

    private func startNewConversation() {
        messages.removeAll()
        activeConversationId = nil
        inputFocused = true
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""
        isLoading = true

        Task {
            do {
                let response = try await SupabaseManager.shared.askJudah(
                    message: text,
                    history: Array(messages.dropLast())
                )
                let assistantMessage = ChatMessage(role: .assistant, content: response)
                messages.append(assistantMessage)

                // Save to server (syncs with web app)
                await saveConversation()
            } catch {
                let errorMessage = ChatMessage(
                    role: .assistant,
                    content: "Sorry, I couldn't connect to the server. Error: \(error.localizedDescription)"
                )
                messages.append(errorMessage)
            }

            isLoading = false
        }
    }

    // MARK: - Helpers

    private func formatRelativeDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else {
            // Try without fractional seconds
            let f2 = ISO8601DateFormatter()
            guard let d2 = f2.date(from: dateString) else { return dateString }
            return RelativeDateTimeFormatter().localizedString(for: d2, relativeTo: Date())
        }
        return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Conversation Model (API sync)

struct Conversation: Codable, Identifiable {
    let id: String
    let title: String
    let messages: [ConversationMessage]
    let model: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, messages, model
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ConversationMessage: Codable {
    let role: String
    let content: String
}

// MARK: - Typing Indicator

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
