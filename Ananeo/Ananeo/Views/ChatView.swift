import SwiftUI

/// Chat between the giver and one requester, about one item. New messages arrive live.
struct ChatView: View {
    @Environment(ChatService.self) private var chat

    let request: PickupRequest
    let itemTitle: String

    @State private var messages: [Message] = []
    @State private var hasLoaded = false
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    private var trimmedDraft: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(messages) { message in
                    MessageBubble(message: message, isMine: message.senderID != request.otherUserID)
                }
            }
            .padding()
        }
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
        .overlay {
            if !hasLoaded {
                ProgressView()
            } else if messages.isEmpty {
                ContentUnavailableView(
                    "No Messages Yet",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Sort out when and where to meet. Keep exact addresses until you've agreed on a time.")
                )
            }
        }
        .safeAreaInset(edge: .bottom) { composer }
        .navigationTitle(request.otherName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(request.otherName).font(.headline)
                    Text(itemTitle).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .task { await load() }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.roundedBorder)
                Button("Send", systemImage: "arrow.up.circle.fill") {
                    Task { await send() }
                }
                .labelStyle(.iconOnly)
                .font(.title)
                .disabled(trimmedDraft.isEmpty || trimmedDraft.count > 2000 || isSending)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    /// Loads the history, then appends new messages until the screen goes away.
    private func load() async {
        do {
            messages = try await chat.messages(in: request.id)
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
        hasLoaded = true
        await chat.markRead(request.id)

        await chat.listen(to: request.id) { message in
            guard append(message) else { return }
            if message.senderID == request.otherUserID {
                Task { await chat.markRead(request.id) }
            }
        }
    }

    private func send() async {
        let body = trimmedDraft
        guard !body.isEmpty else { return }
        errorMessage = nil
        isSending = true
        defer { isSending = false }
        do {
            append(try await chat.send(body, in: request.id))
            draft = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Your own messages come back over realtime too, so skip ones already shown.
    @discardableResult
    private func append(_ message: Message) -> Bool {
        guard !messages.contains(where: { $0.id == message.id }) else { return false }
        messages.append(message)
        return true
    }
}

private struct MessageBubble: View {
    let message: Message
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 48) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                Text(message.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundStyle(isMine ? Color.white : Color.primary)
                    .background(isMine ? Color.accentColor : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                Text(message.createdAt, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !isMine { Spacer(minLength: 48) }
        }
    }
}

#Preview {
    let request = Pickup.preview.requests[0]
    NavigationStack {
        ChatView(request: request, itemTitle: Pickup.preview.title)
    }
    .environment(ChatService.preview())
}
