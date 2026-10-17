import SwiftUI

/// The Pickups tab: everything you're giving or getting, from the first request to a confirmed handoff.
struct PickupsView: View {
    @Environment(PickupService.self) private var pickups

    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                section("Giving", pickups.all.filter { $0.isGiver && $0.stage != .done })
                section("Getting", pickups.all.filter { !$0.isGiver && $0.stage != .done })
                section("Done", pickups.all.filter { $0.stage == .done })
            }
            .overlay {
                if let errorMessage, pickups.all.isEmpty {
                    ContentUnavailableView {
                        Label("Couldn't Load Pickups", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try Again") { Task { await load() } }
                    }
                } else if !pickups.hasLoaded {
                    ProgressView()
                } else if pickups.all.isEmpty {
                    ContentUnavailableView(
                        "No Pickups Yet",
                        systemImage: "arrow.left.arrow.right",
                        description: Text("Ask for something in Browse, or give something away. Requests and handoffs show up here.")
                    )
                }
            }
            .navigationTitle("Pickups")
            .navigationDestination(for: UUID.self) { itemID in
                PickupDetailView(itemID: itemID)
            }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    /// Items waiting on you come first.
    @ViewBuilder
    private func section(_ title: String, _ items: [Pickup]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items.filter(\.needsYou) + items.filter { !$0.needsYou }) { pickup in
                    NavigationLink(value: pickup.id) {
                        PickupRow(pickup: pickup)
                    }
                }
            }
        }
    }

    private func load() async {
        do {
            try await pickups.refresh()
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct PickupRow: View {
    @Environment(ListingService.self) private var listings
    let pickup: Pickup

    var body: some View {
        HStack(spacing: 12) {
            ListingPhoto(url: pickup.photo.flatMap(listings.photoURL), placeholder: pickup.category.systemImage)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(pickup.title)
                    .lineLimit(1)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(pickup.needsYou ? Color.accentColor : Color.secondary)
            }
        }
    }

    private var summary: String {
        let name = pickup.reservation?.otherName ?? pickup.requests.first?.otherName ?? "Someone"
        switch pickup.stage {
        case .open:
            if !pickup.isGiver { return "Asked \(name). Waiting to hear back." }
            return pickup.requests.count == 1 ? "\(name) asked for it" : "\(pickup.requests.count) people asked for it"
        case .reserved:
            guard let handoff = pickup.reservation?.handoff else { return "Reserved" }
            if handoff.confirmedByMe { return "Waiting for \(name) to confirm" }
            if handoff.confirmedByThem { return "\(name) confirmed. Confirm yours." }
            return pickup.isGiver ? "Reserved for \(name)" : "Reserved for you"
        case .done:
            return pickup.isGiver ? "Given to \(name)" : "Received from \(name)"
        case .unavailable:
            return "No longer available"
        }
    }
}

#Preview {
    PickupsView()
        .environment(PickupService.preview([.preview]))
        .environment(ListingService())
}
