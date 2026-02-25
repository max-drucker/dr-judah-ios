import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(attributedContent)
                    .font(.body)
                    .textSelection(.enabled)

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isUser ? Color.drJudahBlue : Color(.secondarySystemBackground))
            )
            .foregroundStyle(isUser ? .white : .primary)

            if !isUser { Spacer(minLength: 60) }
        }
    }

    private var attributedContent: AttributedString {
        (try? AttributedString(markdown: message.content)) ?? AttributedString(message.content)
    }
}
