import Foundation

/// An item the signed-in user is giving or getting, from the first request to a confirmed handoff.
struct Pickup: Identifiable {
    enum Stage {
        /// Available. Givers choose who gets it; receivers wait to be chosen.
        case open
        /// Reserved for the request shown, waiting for both people to confirm.
        case reserved
        /// Both people confirmed. Counts toward impact.
        case done
        /// Reserved for or given to someone else, or removed by the giver.
        case unavailable
    }

    /// The item's ID.
    let id: UUID
    let title: String
    let category: ItemCategory
    let photo: String?
    let status: ItemStatus
    let isGiver: Bool
    /// Givers see everyone who asked, oldest first. Receivers see only their own request.
    let requests: [PickupRequest]

    /// The request the item is reserved for or was handed off to, when it's yours to see.
    var reservation: PickupRequest? { requests.first { $0.handoff != nil } }

    var stage: Stage {
        if let handoff = reservation?.handoff {
            return handoff.completedAt == nil ? .reserved : .done
        }
        return status == .available ? .open : .unavailable
    }

    /// True when the next step is the signed-in user's: choosing someone, or confirming a handoff.
    var needsYou: Bool {
        switch stage {
        case .open: isGiver
        case .reserved: reservation?.handoff?.confirmedByMe == false
        case .done, .unavailable: false
        }
    }
}

/// One person's request for an item.
struct PickupRequest: Identifiable {
    let id: UUID
    /// The requester when you're giving, the giver when you're getting.
    let otherUserID: UUID
    let otherName: String
    let requestedAt: Date
    /// Present only when the item is reserved for or was handed off to this request.
    let handoff: Handoff?
}

/// A reservation, seen from the signed-in user's side.
struct Handoff {
    let id: UUID
    let confirmedByMe: Bool
    let confirmedByThem: Bool
    let completedAt: Date?
}

extension Pickup {
    static let preview = Pickup(
        id: UUID(), title: "Oak bookshelf", category: .furniture, photo: nil, status: .reserved, isGiver: true,
        requests: [
            PickupRequest(
                id: UUID(), otherUserID: UUID(), otherName: "Sam", requestedAt: .now.addingTimeInterval(-7200),
                handoff: Handoff(id: UUID(), confirmedByMe: false, confirmedByThem: true, completedAt: nil)
            ),
            PickupRequest(id: UUID(), otherUserID: UUID(), otherName: "Priya", requestedAt: .now.addingTimeInterval(-3600), handoff: nil),
        ]
    )
}
