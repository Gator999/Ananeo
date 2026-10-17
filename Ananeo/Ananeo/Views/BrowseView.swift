import CoreLocation
import SwiftUI

/// The Browse tab: listings near you, closest first.
struct BrowseView: View {
    @Environment(ListingService.self) private var listings
    @Environment(LocationService.self) private var location

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch location.status {
                case .ready(let coordinate):
                    NearbyFeed(coordinate: coordinate)
                case .locating:
                    ProgressView("Finding your area…")
                case .needsPermission:
                    ContentUnavailableView {
                        Label("See What's Nearby", systemImage: "location.circle")
                    } description: {
                        Text("Ananeo uses your approximate location to show items you can pick up.")
                    } actions: {
                        Button("Use My Location") { location.request() }
                            .buttonStyle(.borderedProminent)
                    }
                case .denied:
                    ContentUnavailableView {
                        Label("Location Is Off", systemImage: "location.slash")
                    } description: {
                        Text("Turn on location for Ananeo in Settings to browse items near you.")
                    } actions: {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Ananeo")
            .navigationDestination(for: Listing.self) { listing in
                ListingDetailView(listing: listing)
            }
        }
        .onAppear { location.request() }
        // Return to the feed when a listing is posted or removed, so the change is visible.
        .onChange(of: listings.revision) { path = NavigationPath() }
    }
}

private struct NearbyFeed: View {
    @Environment(ListingService.self) private var listings
    @Environment(SafetyService.self) private var safety
    let coordinate: CLLocationCoordinate2D

    @State private var category: ItemCategory?
    @State private var radiusMiles: Double = 10
    @State private var appliedRadius: Double = 10
    @State private var results: [Listing] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private struct Query: Equatable {
        let coordinate: CLLocationCoordinate2D
        let category: ItemCategory?
        let radiusMiles: Double
        let revision: Int
        let blocks: Int
    }

    var body: some View {
        List {
            Section {
                Picker("Category", selection: $category) {
                    Text("All").tag(ItemCategory?.none)
                    ForEach(ItemCategory.allCases) { category in
                        Label(category.title, systemImage: category.systemImage)
                            .tag(ItemCategory?.some(category))
                    }
                }
                VStack(alignment: .leading) {
                    Text("Within \(radiusMiles, specifier: "%.0f") mi")
                    // Search only when the slider is released, not on every tick.
                    Slider(value: $radiusMiles, in: 1...25, step: 1) { editing in
                        if !editing { appliedRadius = radiusMiles }
                    }
                }
            }

            Section("Nearby") {
                if let errorMessage {
                    ContentUnavailableView {
                        Label("Couldn't Load Items", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try Again") { Task { await load() } }
                    }
                } else if results.isEmpty && !isLoading {
                    ContentUnavailableView(
                        "Nothing Nearby Yet",
                        systemImage: "tray",
                        description: Text("Try a wider distance or another category, or be the first to give something.")
                    )
                }
                ForEach(results) { listing in
                    NavigationLink(value: listing) {
                        ListingRow(listing: listing)
                    }
                }
            }
        }
        .overlay {
            if isLoading && results.isEmpty { ProgressView() }
        }
        .refreshable { await load() }
        .task(id: Query(coordinate: coordinate, category: category, radiusMiles: appliedRadius, revision: listings.revision, blocks: safety.revision)) {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            results = try await listings.nearby(coordinate, radiusMiles: appliedRadius, category: category)
            errorMessage = nil
        } catch is CancellationError {
            // A newer query replaced this one.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ListingRow: View {
    @Environment(ListingService.self) private var listings
    let listing: Listing

    var body: some View {
        HStack(spacing: 12) {
            ListingPhoto(url: listing.photos.first.flatMap(listings.photoURL), placeholder: listing.category.systemImage)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(listing.title)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let miles = listing.distanceMiles {
                        Text(Distance.label(miles: miles))
                    }
                    if listing.condition == .needsRepair || listing.condition == .forParts {
                        Text("·")
                        Text(listing.condition.title)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(listing.mode.title)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.tint.opacity(0.15), in: Capsule())
        }
    }
}

/// Remote photo with a category icon while loading or when there is none.
struct ListingPhoto: View {
    let url: URL?
    let placeholder: String

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Color.secondary.opacity(0.12)
                    Image(systemName: placeholder)
                        .foregroundStyle(.tint)
                }
            }
        }
    }
}

#Preview {
    BrowseView()
        .environment(ListingService())
        .environment(LocationService())
        .environment(SafetyService())
}
