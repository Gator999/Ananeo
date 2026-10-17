import Foundation
import Observation

/// Sample donation centers until the places table is seeded in Phase 3.
@Observable
final class PlacesStore {
    var donationCenters: [DonationCenter] = [
        DonationCenter(name: "Community Thrift", address: "120 Main St", accepts: [.clothing, .books, .household], distanceMiles: 0.9),
        DonationCenter(name: "Habitat ReStore", address: "48 Industrial Rd", accepts: [.furniture, .tools, .household, .materials], distanceMiles: 2.6),
        DonationCenter(name: "E-Waste Depot", address: "900 Recycling Way", accepts: [.electronics], distanceMiles: 4.2),
    ]
}
