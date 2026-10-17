import Foundation

/// One chat message on a pickup request.
struct Message: Identifiable, Decodable, Equatable {
    let id: UUID
    /// The pickup request this message belongs to.
    let conversationID: UUID
    let senderID: UUID
    let body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case conversationID = "conversation_id"
        case senderID = "sender_id"
        case body
        case createdAt = "created_at"
    }
}

/// The latest message on a request and how many from the other person are unread.
struct ChatSummary: Equatable {
    let lastBody: String
    let lastSenderIsMe: Bool
    let lastAt: Date
    let unreadCount: Int
}

extension Message {
    static func preview(_ body: String, from senderID: UUID, minutesAgo: Double) -> Message {
        Message(id: UUID(), conversationID: UUID(), senderID: senderID, body: body, createdAt: .now.addingTimeInterval(-minutesAgo * 60))
    }
}
