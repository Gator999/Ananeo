import SwiftUI

/// The chat between a giver and one person who asked for their item.
struct ChatView: View {
    @Environment(ChatService.self) private var chat
    @Environment(AuthService.self) private var auth
    @Environment(\.scenePhase) private var scenePhase

    let conversationID: UUID
    let otherName: String

    @State private var draft = ""
    @State private var isSending = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?

    private var messages: [Message] { chat.messages(in: conversationID) }

    private var myID: UUID? {
        if case .signedIn(let userID) = auth.state { userID } else { nil }
    }

    private var trimmedDraft: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canSend: Bool {
        !trimmedDraft.isEmpty && trimmedDraft.count <= ChatService.maxLength && !isSending
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        if startsNewGroup(at: index) {
                            Text(message.createdAt, format: .dateTime.weekday().hour().minute())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                        MessageBubble(message: message, isMine: message.senderID == myID)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.last?.id) {
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    if last.senderID != myID {
                        Task { await chat.markRead(conversationID) }
                    }
                }
            }
        }
        .overlay {
            if messages.isEmpty {
                if hasLoaded {
                    ContentUnavailableView(
                        "Say Hello",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Agree on a time with \(otherName), and meet somewhere public if you can.")
                    )
                } else if errorMessage == nil {
                    ProgressView()
                }
            }
        }
        .safeAreaInset(edge: .bottom) { composer }
        .navigationTitle(otherName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        // Realtime pauses in the background, so catch up on return.
        .onChange(of: scenePhase) {
            if scenePhase == .active { Task { await load() } }
        }
    }

    private var composer: some View {
        VStack(spacing: 4) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                }
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    /// Shows a time above the first message, and above any message sent after a long pause.
    private func startsNewGroup(at index: Int) -> Bool {
        guard index > 0 else { return true }
        return messages[index].createdAt.timeIntervalSince(messages[index - 1].createdAt) > 60 * 60
    }

    private func load() async {
        do {
            try await chat.load(conversationID)
            errorMessage = nil
            await chat.markRead(conversationID)
        } catch is CancellationError {
        } catch {
            errorMessage = "Couldn't load messages: \(error.localizedDescription)"
        }
        hasLoaded = true
    }

    private func send() async {
        let body = trimmedDraft
        errorMessage = nil
        isSending = true
        defer { isSending = false }
        do {
            try await chat.send(body, in: conversationID)
            draft = ""
        } catch {
            errorMessage = "Couldn't send: \(error.localizedDescription)"
        }
    }
}

private struct MessageBubble: View {
    let message: Message
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 48) }
            Text(message.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(isMine ? Color.white : Color.primary)
                .background(isMine ? Color.accentColor : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                .textSelection(.enabled)
            if !isMine { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isMine ? "You: \(message.body)" : message.body)
    }
}

#Preview {
    let conversationID = UUID()
    let me = UUID()
    return NavigationStack {
        ChatView(conversationID: conversationID, otherName: "Sam")
    }
    .environment(ChatService.preview([
        Message(id: UUID(), conversationID: conversationID, senderID: UUID(), body: "Could I pick it up Saturday?", createdAt: .now.addingTimeInterval(-7200)),
        Message(id: UUID(), conversationID: conversationID, senderID: me, body: "Saturday at 10 works.", createdAt: .now.addingTimeInterval(-7000)),
    ]))
    .environment(AuthService())
}
