import Foundation
import Observation
import Supabase

/// Chat on pickup requests. Keeps the threads that have been opened in memory, and listens for
/// new messages on one Realtime channel for the whole app.
@MainActor
@Observable
final class ChatService {
    static let maxLength = 2000
    static let pageSize = 200

    /// Messages for each conversation seen so far, oldest first.
    private(set) var threads: [UUID: [Message]] = [:]
    /// Bumped when messages arrive, a chat is read, or a handoff changes, so pickups know to reload.
    private(set) var revision = 0

    @ObservationIgnored private let client: SupabaseClient

    init(client: SupabaseClient = Backend.client) {
        self.client = client
    }

    func messages(in conversationID: UUID) -> [Message] {
        threads[conversationID] ?? []
    }

    /// Forgets everything, for when the signed-in account changes.
    func reset() {
        threads = [:]
    }

    /// For SwiftUI previews.
    static func preview(_ messages: [Message]) -> ChatService {
        let service = ChatService()
        service.add(messages)
        return service
    }

    // MARK: - Reading and writing

    /// Loads the latest messages in a conversation.
    func load(_ conversationID: UUID) async throws {
        let latest: [Message] = try await client.from("messages")
            .select()
            .eq("conversation_id", value: conversationID)
            .order("created_at", ascending: false)
            .limit(Self.pageSize)
            .execute()
            .value
        add(latest)
    }

    private struct NewMessage: Encodable {
        let conversation_id: UUID
        let body: String
    }

    func send(_ body: String, in conversationID: UUID) async throws {
        let message: Message = try await client.from("messages")
            .insert(NewMessage(conversation_id: conversationID, body: body), returning: .representation)
            .select()
            .single()
            .execute()
            .value
        add([message])
        revision += 1
    }

    /// Marks everything in the conversation as read by the signed-in user.
    func markRead(_ conversationID: UUID) async {
        do {
            try await client.rpc("mark_conversation_read", params: ["p_conversation_id": conversationID]).execute()
            revision += 1
        } catch {
            // The unread count stays until the next time the chat is opened.
        }
    }

    // MARK: - Realtime

    /// Receives new messages, and reservations and confirmations, for everything the signed-in user
    /// is part of, until the calling task is cancelled. Row Level Security limits both streams to the
    /// user's own rows. Handoff deletes aren't requested because Realtime sends those to everyone.
    func listen() async {
        let channel = client.channel("pickups")
        let inserts = channel.postgresChange(InsertAction.self, schema: "public", table: "messages")
        let reservations = channel.postgresChange(InsertAction.self, schema: "public", table: "handoffs")
        let confirmations = channel.postgresChange(UpdateAction.self, schema: "public", table: "handoffs")

        // Keep trying while offline. Once subscribed, the client rejoins after reconnects by itself.
        var delay: Duration = .seconds(2)
        while !Task.isCancelled {
            do {
                try await channel.subscribeWithError()
                break
            } catch {
                try? await Task.sleep(for: delay)
                delay = min(delay * 2, .seconds(60))
            }
        }

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await insert in inserts {
                    guard let message = try? insert.decodeRecord(as: Message.self, decoder: AnyJSON.decoder) else { continue }
                    await self.received(message)
                }
            }
            group.addTask {
                for await _ in reservations { await self.handoffChanged() }
            }
            group.addTask {
                for await _ in confirmations { await self.handoffChanged() }
            }
        }

        await client.removeChannel(channel)
    }

    private func received(_ message: Message) {
        add([message])
        revision += 1
    }

    private func handoffChanged() {
        revision += 1
    }

    /// Merges messages into their threads. The same message can arrive from a load, a send,
    /// and Realtime, so they are matched by ID.
    private func add(_ messages: [Message]) {
        for (conversationID, incoming) in Dictionary(grouping: messages, by: \.conversationID) {
            var byID = Dictionary(uniqueKeysWithValues: (threads[conversationID] ?? []).map { ($0.id, $0) })
            for message in incoming { byID[message.id] = message }
            threads[conversationID] = byID.values.sorted {
                ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString)
            }
        }
    }
}
