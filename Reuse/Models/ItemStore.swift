import Foundation
import Observation

@Observable
final class ItemStore {
    var items: [Item]
    var donationCenters: [DonationCenter]

    init() {
        items = ItemStore.sampleItems
        donationCenters = ItemStore.sampleCenters
    }

    // MARK: - Actions

    func add(_ item: Item) {
        items.insert(item, at: 0)
    }

    func markExchanged(_ item: Item) {
        guard let index = items.firstIndex(of: item) else { return }
        items[index].status = .exchanged
    }

    func items(in category: ItemCategory?, within maxDistanceKm: Double) -> [Item] {
        items
            .filter { $0.status == .available }
            .filter { category == nil || $0.category == category }
            .filter { $0.distanceKm <= maxDistanceKm }
            .sorted { $0.distanceKm < $1.distanceKm }
    }

    // MARK: - Impact

    var exchangedItems: [Item] {
        items.filter { $0.status == .exchanged }
    }

    var kilogramsDiverted: Double {
        exchangedItems.reduce(0) { $0 + $1.category.estimatedKilograms }
    }

    // MARK: - Sample data

    static let sampleItems: [Item] = [
        Item(title: "Oak bookshelf", details: "Solid wood, five shelves. Needs a pickup truck.", category: .furniture, distanceKm: 1.2),
        Item(title: "Winter coats (3)", details: "Adult medium, lightly worn.", category: .clothing, distanceKm: 0.4),
        Item(title: "27-inch monitor", details: "Works fine, one dead pixel.", category: .electronics, distanceKm: 3.8),
        Item(title: "Cordless drill", details: "Includes charger and two batteries.", category: .tools, distanceKm: 2.1),
        Item(title: "Box of paperbacks", details: "Mostly sci-fi and mystery.", category: .books, distanceKm: 0.9),
        Item(title: "Kitchen pots and pans", details: "Full set, non-stick.", category: .household, distanceKm: 5.5),
        Item(title: "Desk lamp", details: "LED, adjustable arm.", category: .household, distanceKm: 1.7, status: .exchanged),
    ]

    static let sampleCenters: [DonationCenter] = [
        DonationCenter(name: "Community Thrift", address: "120 Main St", accepts: [.clothing, .books, .household], distanceKm: 1.5),
        DonationCenter(name: "Habitat ReStore", address: "48 Industrial Rd", accepts: [.furniture, .tools, .household], distanceKm: 4.2),
        DonationCenter(name: "E-Waste Depot", address: "900 Recycling Way", accepts: [.electronics], distanceKm: 6.8),
    ]
}
