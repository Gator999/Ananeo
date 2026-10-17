import CoreLocation
import SwiftUI

/// The Browse tab: listings near you, closest first, as a grid of photos.
struct BrowseView: View {
    @Environment(ListingService.self) private var listings
    @Environment(LocationService.self) private var location

    @State private var path = NavigationPath()
    @Namespace private var zoom

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch location.status {
                case .ready(let coordinate):
                    NearbyFeed(coordinate: coordinate, zoom: zoom)
                case .locating:
                    VStack(spacing: AnaneoTheme.Spacing.lg) {
                        LoopRing(progress: nil, lineWidth: 6).frame(width: 44)
                        Text("Finding your area…").foregroundStyle(AnaneoTheme.smoke)
                    }
                case .needsPermission:
                    ContentUnavailableView {
                        Label("See What's Nearby", systemImage: "location.circle")
                    } description: {
                        Text("Ananeo uses your approximate location to show items you can pick up.")
                    } actions: {
                        Button("Use My Location") { location.request() }
                            .buttonStyle(.pill(.primary, expanded: false))
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
                        .buttonStyle(.pill(.secondary, expanded: false))
                    }
                }
            }
            .background(AnaneoTheme.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Listing.self) { listing in
                ListingDetailView(listing: listing)
                    // The card's photo grows into the hero, and dragging the hero down comes back.
                    .navigationTransition(.zoom(sourceID: listing.id, in: zoom))
            }
        }
        .onAppear { location.request() }
        // Return to the feed when a listing is posted or removed, so the change is visible.
        .onChange(of: listings.revision) { path = NavigationPath() }
    }
}

private struct NearbyFeed: View {
    @Environment(ListingService.self) private var listings
    let coordinate: CLLocationCoordinate2D
    let zoom: Namespace.ID

    @State private var category: ItemCategory?
    @State private var mode: ItemMode?
    @State private var radiusMiles: Double = 10
    @State private var results: [Listing] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private static let radiusChoices: [Double] = [1, 2, 5, 10, 25]
    private let columns = [
        GridItem(.flexible(), spacing: AnaneoTheme.Spacing.lg - 2),
        GridItem(.flexible(), spacing: AnaneoTheme.Spacing.lg - 2),
    ]

    private struct Query: Equatable {
        let coordinate: CLLocationCoordinate2D
        let category: ItemCategory?
        let mode: ItemMode?
        let radiusMiles: Double
        let revision: Int
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AnaneoTheme.Spacing.lg) {
                header
                filters
                categoryChips
                CommunityStrip()
                content
            }
            .padding(.horizontal, AnaneoTheme.Spacing.xl)
            .padding(.bottom, AnaneoTheme.Spacing.xxl)
        }
        .refreshable { await load() }
        .task(id: Query(coordinate: coordinate, category: category, mode: mode, radiusMiles: radiusMiles, revision: listings.revision)) {
            await load()
        }
        .sensoryFeedback(.selection, trigger: category)
        .sensoryFeedback(.selection, trigger: mode)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.xs + 2) {
            Text("Your area").sectionLabel()
            Text("Near you")
                .displayTitle()
                .foregroundStyle(AnaneoTheme.ink)
        }
        .padding(.top, AnaneoTheme.Spacing.sm)
        .accessibilityAddTraits(.isHeader)
    }

    private var filters: some View {
        HStack(spacing: AnaneoTheme.Spacing.sm) {
            Menu {
                Picker("Distance", selection: $radiusMiles) {
                    ForEach(Self.radiusChoices, id: \.self) { miles in
                        Text("Within \(miles, specifier: "%.0f") mi").tag(miles)
                    }
                }
            } label: {
                Chip(title: "Within \(Int(radiusMiles)) mi", systemImage: "location")
            }
            Menu {
                Picker("Offer", selection: $mode) {
                    Text("Any offer").tag(ItemMode?.none)
                    ForEach(ItemMode.allCases) { mode in
                        Text(mode.pickerTitle).tag(ItemMode?.some(mode))
                    }
                }
            } label: {
                Chip(title: mode?.pickerTitle ?? "Any offer", systemImage: "chevron.down")
            }
        }
    }

    /// Bleeds to the screen edges so the last chip peeks in from the right.
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AnaneoTheme.Spacing.sm) {
                Button { category = nil } label: {
                    Chip(title: "All", isSelected: category == nil)
                }
                ForEach(ItemCategory.allCases) { item in
                    Button { category = item } label: {
                        Chip(title: item.title, systemImage: item.systemImage, isSelected: category == item)
                    }
                }
            }
            .padding(.horizontal, AnaneoTheme.Spacing.xl)
            .padding(.vertical, AnaneoTheme.Spacing.xs)
        }
        .buttonStyle(.plain)
        .scrollClipDisabled()
        .padding(.horizontal, -AnaneoTheme.Spacing.xl)
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage {
            ContentUnavailableView {
                Label("Couldn't Load Items", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") { Task { await load() } }
                    .buttonStyle(.pill(.secondary, expanded: false))
            }
            .padding(.top, AnaneoTheme.Spacing.xxl)
        } else if results.isEmpty && isLoading {
            LazyVGrid(columns: columns, spacing: AnaneoTheme.Spacing.lg) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.sm) {
                        Skeleton(cornerRadius: AnaneoTheme.Radius.card).aspectRatio(4 / 5, contentMode: .fit)
                        Skeleton().frame(height: 14)
                        Skeleton().frame(width: 80, height: 12)
                    }
                }
            }
        } else if results.isEmpty {
            ContentUnavailableView(
                "Nothing Nearby Yet",
                systemImage: "tray",
                description: Text("Try a wider distance or another category, or be the first to give something.")
            )
            .padding(.top, AnaneoTheme.Spacing.xxl)
        } else {
            LazyVGrid(columns: columns, spacing: AnaneoTheme.Spacing.lg) {
                ForEach(results) { listing in
                    NavigationLink(value: listing) {
                        ListingCard(listing: listing)
                    }
                    .buttonStyle(.plain)
                    .matchedTransitionSource(id: listing.id, in: zoom)
                    .easeInOnScroll()
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            results = try await listings.nearby(coordinate, radiusMiles: radiusMiles, category: category, mode: mode)
            errorMessage = nil
        } catch is CancellationError {
            // A newer query replaced this one.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Everyone's totals, hidden until they load so the feed never waits on them.
private struct CommunityStrip: View {
    @Environment(ListingService.self) private var listings
    @State private var community: CommunityImpact?

    var body: some View {
        Group {
            if let community {
                CommunityCard(community: community)
            }
        }
        .task(id: listings.revision) {
            community = try? await listings.communityImpact()
        }
    }
}

#Preview {
    BrowseView()
        .environment(ListingService())
        .environment(LocationService())
        .environment(PickupService())
        .environment(AuthService())
}
