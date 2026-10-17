import Foundation

/// A listing as returned by the `nearby_items` function or a select on `items`.
struct Listing: Identifiable, Hashable, Decodable {
    let id: UUID
    let ownerID: UUID
    let title: String
    let details: String
    let category: ItemCategory
    let condition: ItemCondition
    let mode: ItemMode
    let status: ItemStatus
    let wants: String?
    let estKg: Double
    let photos: [String]
    let createdAt: Date
    /// Present only in nearby results. Already fuzzed by the server.
    let distanceKm: Double?

    var distanceMiles: Double? { distanceKm.map(Distance.miles(fromKm:)) }

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case title, details, category, condition, mode, status, wants
        case estKg = "est_kg"
        case photos
        case createdAt = "created_at"
        case distanceKm = "distance_km"
    }
}

/// What the Give form collects before posting.
struct ListingDraft {
    var title = ""
    var details = ""
    var category: ItemCategory = .household
    var condition: ItemCondition = .good
    var mode: ItemMode = .give
    var wants = ""

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
}

struct Impact: Decodable, Equatable {
    var itemsGiven: Int = 0
    var itemsReceived: Int = 0
    var kgDiverted: Double = 0

    enum CodingKeys: String, CodingKey {
        case itemsGiven = "items_given"
        case itemsReceived = "items_received"
        case kgDiverted = "kg_diverted"
    }
}

struct CommunityImpact: Decodable, Equatable {
    var itemsKeptMoving: Int = 0
    var kgDiverted: Double = 0

    enum CodingKeys: String, CodingKey {
        case itemsKeptMoving = "items_kept_moving"
        case kgDiverted = "kg_diverted"
    }
}

extension Listing {
    static let preview = Listing(
        id: UUID(), ownerID: UUID(), title: "Oak bookshelf",
        details: "Solid wood, five shelves. Needs a pickup truck.",
        category: .furniture, condition: .good, mode: .give, status: .available,
        wants: nil, estKg: 25, photos: [], createdAt: .now, distanceKm: 1.9
    )
}
