import Foundation
import Observation
import Supabase

/// Chat between the giver and a requester, one conversation per pickup request.
/// Keeps an inbox summary per request so the Pickups tab can show the latest message and unread counts.
@MainActor
@Observable
final class ChatService {
    /// Keyed by pickup request (conversation) ID. Requests with no messages have no entry.
    private(set) var summaries: [UUID: ChatSummary] = [:]

    @ObservationIgnored private let client: SupabaseClient

    init(client: SupabaseClient = Backend.client) {
        self.client = client
    }

    func summary(for request: PickupRequest) -> ChatSummary? {
        summaries[request.id]
    }

    /// Unread messages across the given pickups. Requests that no longer exist don't count.
    func unreadCount(in pickups: [Pickup]) -> Int {
        pickups.reduce(0) { $0 + unreadCount(in: $1) }
    }

    func unreadCount(in pickup: Pickup) -> Int {
        pickup.requests.reduce(0) { $0 + (summaries[$1.id]?.unreadCount ?? 0) }
    }

    // MARK: - Inbox

    /// One row per conversation with messages, as returned by `my_chats`.
    private struct Row: Decodable {
        let conversation_id: UUID
        let last_body: String
        let last_sender_is_me: Bool
        let last_at: Date
        let unread_count: Int
    }

    func refresh() async throws {
        let rows: [Row] = try await client.rpc("my_chats").execute().value
        summaries = Dictionary(uniqueKeysWithValues: rows.map {
            ($0.conversation_id, ChatSummary(lastBody: $0.last_body, lastSenderIsMe: $0.last_sender_is_me, lastAt: $0.last_at, unreadCount: $0.unread_count))
        })
    }

    /// Keeps the inbox current while the signed-in tabs are showing. Returns when the task is cancelled.
    func watchInbox() async {
        try? await refresh()
        await listen(to: nil) { [weak self] _ in
            Task { try? await self?.refresh() }
        }
    }

    /// Forgets everything, for when the signed-in account changes.
    func reset() {
        summaries = [:]
    }

    /// For SwiftUI previews.
    static func preview(_ summaries: [UUID: ChatSummary] = [:]) -> ChatService {
        let service = ChatService()
        service.summaries = summaries
        return service
    }

    // MARK: - One conversation

    /// The most recent messages, oldest first.
    func messages(in conversationID: UUID, limit: Int = 200) async throws -> [Message] {
        let newestFirst: [Message] = try await client.from("messages")
            .select()
            .eq("conversation_id", value: conversationID)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return newestFirst.reversed()
    }

    private struct NewMessage: Encodable {
        let conversation_id: UUID
        let body: String
    }

    struct BlockedError: LocalizedError {
        var errorDescription: String? { "You can't message this person." }
    }

    /// Sends a message. The server stamps the sender and time.
    func send(_ body: String, in conversationID: UUID) async throws -> Message {
        do {
            return try await client.from("messages")
                .insert(NewMessage(conversation_id: conversationID, body: body))
                .select()
                .single()
                .execute()
                .value
        } catch let error as PostgrestError where error.code == "42501" {
            // Blocked, or the request was withdrawn since the chat opened.
            throw BlockedError()
        }
    }

    /// Marks the conversation read up to now.
    func markRead(_ conversationID: UUID) async {
        guard (try? await client.rpc("mark_conversation_read", params: ["p_conversation_id": conversationID]).execute()) != nil else { return }
        if let summary = summaries[conversationID], summary.unreadCount > 0 {
            summaries[conversationID] = ChatSummary(lastBody: summary.lastBody, lastSenderIsMe: summary.lastSenderIsMe, lastAt: summary.lastAt, unreadCount: 0)
        }
    }

    /// Calls `onMessage` for each new message in one conversation, or in every conversation the
    /// signed-in user is part of when `conversationID` is nil. Row level security decides what arrives.
    /// Returns when the task is cancelled.
    func listen(to conversationID: UUID?, onMessage: @escaping @MainActor (Message) -> Void) async {
        let channel = client.channel("messages-\(conversationID?.uuidString ?? "all")-\(UUID().uuidString)")
        let inserts = channel.postgresChange(
            InsertAction.self,
            table: "messages",
            filter: conversationID.map { .eq("conversation_id", value: $0) }
        )
        do {
            try await channel.subscribeWithError()
            for await insert in inserts {
                if let message = try? insert.decodeRecord(as: Message.self, decoder: AnyJSON.decoder) {
                    onMessage(message)
                }
            }
        } catch {
            // Couldn't subscribe. Pull to refresh still works.
        }
        await client.removeChannel(channel)
    }
}
