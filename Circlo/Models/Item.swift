import Foundation

enum ItemCategory: String, CaseIterable, Identifiable, Codable {
    case furniture, clothing, electronics, tools, books, household

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .furniture: "sofa"
        case .clothing: "tshirt"
        case .electronics: "desktopcomputer"
        case .tools: "wrench.and.screwdriver"
        case .books: "book"
        case .household: "house"
        }
    }

    /// Rough average weight in kilograms, used for the waste-diverted estimate.
    var estimatedKilograms: Double {
        switch self {
        case .furniture: 25
        case .clothing: 0.5
        case .electronics: 3
        case .tools: 2
        case .books: 0.8
        case .household: 1.5
        }
    }
}

enum ItemStatus: String, Codable {
    case available, claimed, exchanged
}

struct Item: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var details: String
    var category: ItemCategory
    var distanceKm: Double
    var isFree: Bool = true
    var status: ItemStatus = .available
    var listedAt = Date()
}

struct DonationCenter: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let address: String
    let accepts: [ItemCategory]
    let distanceKm: Double
}
