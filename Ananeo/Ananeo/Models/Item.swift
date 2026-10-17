import Foundation

// These enums mirror the Postgres enums in supabase/migrations. Raw values must match exactly.

enum ItemCategory: String, CaseIterable, Identifiable, Codable {
    case furniture, clothing, electronics, tools, books, household, materials, other

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
        case .materials: "shippingbox"
        case .other: "square.grid.2x2"
        }
    }
}

enum ItemCondition: String, CaseIterable, Identifiable, Codable {
    case likeNew = "like_new"
    case good
    case worn
    case needsRepair = "needs_repair"
    case forParts = "for_parts"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .likeNew: "Like new"
        case .good: "Good"
        case .worn: "Worn"
        case .needsRepair: "Needs repair"
        case .forParts: "For parts"
        }
    }
}

enum ItemMode: String, CaseIterable, Identifiable, Codable {
    case give, swap, parts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .give: "Free"
        case .swap: "Swap"
        case .parts: "Parts"
        }
    }

    var pickerTitle: String {
        switch self {
        case .give: "Give away"
        case .swap: "Swap"
        case .parts: "Parts"
        }
    }
}

enum ItemStatus: String, Codable {
    case available, reserved
    case handedOff = "handed_off"
    case removed
}
