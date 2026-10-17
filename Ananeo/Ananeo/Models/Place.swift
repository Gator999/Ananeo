import CoreLocation
import Foundation
import SwiftUI

/// What a place takes in. Mirrors the Postgres enum; raw values must match exactly.
enum PlaceKind: String, CaseIterable, Identifiable, Codable {
    case donation, repair, ewaste, textile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .donation: "Donation"
        case .repair: "Repair"
        case .ewaste: "E-waste"
        case .textile: "Textile"
        }
    }

    var systemImage: String {
        switch self {
        case .donation: "shippingbox"
        case .repair: "wrench.and.screwdriver"
        case .ewaste: "desktopcomputer"
        case .textile: "tshirt"
        }
    }
}

extension AnaneoTheme {
    /// The pin and tile color for a kind of place.
    static func color(for kind: PlaceKind) -> Color {
        switch kind {
        case .donation: leaf
        case .repair: clay
        case .ewaste: sky
        case .textile: sun
        }
    }
}

/// A donation center, repair café, e-waste drop-off, or textile bin, as returned by `nearby_places`.
struct Place: Identifiable, Hashable, Decodable {
    let id: UUID
    let kind: PlaceKind
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let accepts: [ItemCategory]
    let hours: String?
    let website: String?
    let verified: Bool
    let distanceKm: Double

    enum CodingKeys: String, CodingKey {
        case id, kind, name, address, latitude, longitude, accepts, hours, website, verified
        case distanceKm = "distance_km"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var distanceMiles: Double { Distance.miles(fromKm: distanceKm) }
}

extension Place {
    static let samples: [Place] = [
        Place(id: UUID(), kind: .donation, name: "Community Thrift", address: "120 Main St", latitude: 40.6790, longitude: -73.9440,
              accepts: [.clothing, .books, .household], hours: "Mon–Sat 10–6", website: nil, verified: true, distanceKm: 1.4),
        Place(id: UUID(), kind: .repair, name: "Fix-It Café", address: "5 Repair Row", latitude: 40.6820, longitude: -73.9500,
              accepts: [.electronics, .tools], hours: "Second Saturday, 12–4", website: nil, verified: false, distanceKm: 2.1),
        Place(id: UUID(), kind: .ewaste, name: "E-Waste Depot", address: "900 Recycling Way", latitude: 40.6700, longitude: -73.9300,
              accepts: [.electronics], hours: nil, website: "https://example.com", verified: true, distanceKm: 4.2),
    ]
}
