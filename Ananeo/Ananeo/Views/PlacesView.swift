import MapKit
import SwiftUI

/// The Places tab: where things go when no one claims them. A map with pins by kind, glass filter chips, and a sheet of cards.
struct PlacesView: View {
    @Environment(PlaceService.self) private var service
    @Environment(LocationService.self) private var location

    @State private var kind: PlaceKind?
    @State private var places: [Place] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selection: Place.ID?
    @State private var position: MapCameraPosition = .automatic

    private let radiusMiles: Double = 10

    private struct Query: Equatable {
        let coordinate: CLLocationCoordinate2D
        let kind: PlaceKind?
    }

    var body: some View {
        Group {
            switch location.status {
            case .ready(let coordinate):
                map(around: coordinate)
            case .locating:
                VStack(spacing: AnaneoTheme.Spacing.lg) {
                    LoopRing(progress: nil, lineWidth: 6).frame(width: 44)
                    Text("Finding your area…").foregroundStyle(AnaneoTheme.smoke)
                }
            case .needsPermission:
                ContentUnavailableView {
                    Label("Places Near You", systemImage: "mappin.and.ellipse")
                } description: {
                    Text("Ananeo uses your approximate location to find donation centers and repair cafés nearby.")
                } actions: {
                    Button("Use My Location") { location.request() }
                        .buttonStyle(.pill(.primary, expanded: false))
                }
            case .denied:
                ContentUnavailableView {
                    Label("Location Is Off", systemImage: "location.slash")
                } description: {
                    Text("Turn on location for Ananeo in Settings to see places near you.")
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
        .onAppear { location.request() }
    }

    private func map(around coordinate: CLLocationCoordinate2D) -> some View {
        ZStack(alignment: .top) {
            PlacesMap(places: places, selection: $selection, position: $position)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.md) {
                titleRow(coordinate)
                filterChips
            }
            .padding(.horizontal, AnaneoTheme.Spacing.lg)
            .padding(.top, AnaneoTheme.Spacing.sm)
        }
        .overlay(alignment: .bottom) {
            PlaceSheet(places: places, radiusMiles: radiusMiles, isLoading: isLoading, errorMessage: errorMessage, selection: $selection) {
                Task { await load(coordinate) }
            }
        }
        .task(id: Query(coordinate: coordinate, kind: kind)) {
            await load(coordinate)
        }
        .onChange(of: selection) { _, id in
            guard let place = places.first(where: { $0.id == id }) else { return }
            withAnimation(AnaneoMotion.settle()) {
                position = .region(MKCoordinateRegion(center: place.coordinate, latitudinalMeters: 2500, longitudinalMeters: 2500))
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func titleRow(_ coordinate: CLLocationCoordinate2D) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Places")
                    .font(.title.weight(.heavy))
                    .tracking(-0.5)
                    .foregroundStyle(AnaneoTheme.ink)
                Text("Where things go when no one claims them")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AnaneoTheme.smoke)
            }
            .padding(.horizontal, AnaneoTheme.Spacing.lg)
            .padding(.vertical, AnaneoTheme.Spacing.sm + 2)
            .glass(in: RoundedRectangle(cornerRadius: AnaneoTheme.Radius.card, style: .continuous))
            .accessibilityAddTraits(.isHeader)
            Spacer()
            Button {
                selection = nil
                withAnimation(AnaneoMotion.settle()) {
                    position = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 8000, longitudinalMeters: 8000))
                }
            } label: {
                Image(systemName: "location.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AnaneoTheme.leaf)
                    .frame(width: 44, height: 44)
                    .glass()
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Center on my location")
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AnaneoTheme.Spacing.sm) {
                Button { kind = nil } label: {
                    Chip(title: "All", isSelected: kind == nil)
                }
                ForEach(PlaceKind.allCases) { placeKind in
                    Button { kind = placeKind } label: {
                        HStack(spacing: AnaneoTheme.Spacing.xs + 3) {
                            Circle().fill(AnaneoTheme.color(for: placeKind)).frame(width: 10, height: 10)
                            Text(placeKind.title)
                        }
                        .font(AnaneoTheme.Typography.chip)
                        .foregroundStyle(kind == placeKind ? AnaneoTheme.canvas : AnaneoTheme.ink)
                        .padding(.horizontal, AnaneoTheme.Spacing.md)
                        .frame(height: AnaneoTheme.Size.chip)
                        .background {
                            if kind == placeKind {
                                Capsule().fill(AnaneoTheme.ink)
                            } else {
                                GlassBackground(shape: Capsule())
                            }
                        }
                        .accessibilityAddTraits(kind == placeKind ? .isSelected : [])
                    }
                }
            }
            .padding(.horizontal, AnaneoTheme.Spacing.lg)
            .padding(.vertical, AnaneoTheme.Spacing.xs)
        }
        .buttonStyle(.plain)
        .scrollClipDisabled()
        .padding(.horizontal, -AnaneoTheme.Spacing.lg)
        .sensoryFeedback(.selection, trigger: kind)
    }

    private func load(_ coordinate: CLLocationCoordinate2D) async {
        isLoading = true
        defer { isLoading = false }
        do {
            places = try await service.nearby(coordinate, radiusMiles: radiusMiles, kind: kind)
            errorMessage = nil
            if places.isEmpty || position == .automatic {
                position = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 8000, longitudinalMeters: 8000))
            }
            if let selection, !places.contains(where: { $0.id == selection }) {
                self.selection = nil
            }
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    PlacesView()
        .environment(PlaceService())
        .environment(LocationService())
}
