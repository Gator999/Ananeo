import Foundation

/// What anyone signed in can see about a person, as returned by `public_profile`.
struct PublicProfile: Identifiable, Decodable, Equatable {
    let id: UUID
    let displayName: String
    /// Handoffs they have completed, giving or receiving.
    let itemsKeptMoving: Int
    let memberSince: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case itemsKeptMoving = "items_kept_moving"
        case memberSince = "member_since"
    }

    init(id: UUID, displayName: String, itemsKeptMoving: Int, memberSince: Date) {
        self.id = id
        self.displayName = displayName
        self.itemsKeptMoving = itemsKeptMoving
        self.memberSince = memberSince
    }

    /// The first letter of the name, for the avatar.
    var initial: String {
        displayName.first.map { String($0).uppercased() } ?? "?"
    }
}

extension PublicProfile {
    static let preview = PublicProfile(id: UUID(), displayName: "Sam", itemsKeptMoving: 12, memberSince: .now.addingTimeInterval(-86400 * 90))
    /// Stands in while the real card loads, under a redaction.
    static let placeholder = PublicProfile(id: UUID(), displayName: "Neighbor", itemsKeptMoving: 10, memberSince: .now)
}
