import MapKit
import SwiftUI

/// The panel over the map: nearby places as cards, with the chosen one ringed in its color at the top.
/// Drag the handle to show more or less of the list.
struct PlaceSheet: View {
    let places: [Place]
    let radiusMiles: Double
    let isLoading: Bool
    let errorMessage: String?
    @Binding var selection: Place.ID?
    var onRetry: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let peek = min(360, geometry.size.height * 0.46)
            let full = geometry.size.height - 120
            let height = max(peek, min(full, (isExpanded ? full : peek) - dragOffset))

            VStack(spacing: AnaneoTheme.Spacing.md) {
                handle
                header
                list
            }
            .padding(.horizontal, AnaneoTheme.Spacing.xl)
            .frame(maxWidth: .infinity)
            .frame(height: height, alignment: .top)
            .background(
                AnaneoTheme.canvas,
                in: UnevenRoundedRectangle(topLeadingRadius: 28, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 28, style: .continuous)
            )
            .shadow(color: AnaneoTheme.shadow.opacity(0.14), radius: 20, y: -12)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .animation(AnaneoMotion.settle(reduceMotion: reduceMotion), value: isExpanded)
        }
    }

    private var handle: some View {
        Capsule()
            .fill(AnaneoTheme.track)
            .frame(width: 40, height: 5)
            .padding(.top, AnaneoTheme.Spacing.sm + 2)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { dragOffset = $0.translation.height }
                    .onEnded { value in
                        dragOffset = 0
                        if value.translation.height < -40 { isExpanded = true }
                        if value.translation.height > 40 { isExpanded = false }
                    }
            )
            .accessibilityLabel(isExpanded ? "Show less" : "Show more")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { isExpanded.toggle() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Nearby")
                .font(.headline)
                .foregroundStyle(AnaneoTheme.ink)
            Spacer()
            if !places.isEmpty {
                (Text(places.count, format: .number).bold() + Text(places.count == 1 ? " place within " : " places within ") + Text("\(radiusMiles, specifier: "%.0f") mi"))
                    .font(.footnote)
                    .foregroundStyle(AnaneoTheme.smoke)
            }
        }
    }

    @ViewBuilder
    private var list: some View {
        if let errorMessage {
            ContentUnavailableView {
                Label("Couldn't Load Places", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again", action: onRetry)
                    .buttonStyle(.pill(.secondary, expanded: false))
            }
        } else if isLoading && places.isEmpty {
            VStack(spacing: AnaneoTheme.Spacing.md) {
                ForEach(0..<3, id: \.self) { _ in
                    Skeleton(cornerRadius: AnaneoTheme.Radius.card).frame(height: 96)
                }
            }
        } else if places.isEmpty {
            ContentUnavailableView(
                "No Places Nearby Yet",
                systemImage: "mappin.slash",
                description: Text("Ananeo adds donation centers, repair cafés, and drop-offs city by city. This area is next.")
            )
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: AnaneoTheme.Spacing.md) {
                        ForEach(places) { place in
                            PlaceCard(place: place, isSelected: place.id == selection) {
                                selection = place.id
                            }
                            .id(place.id)
                        }
                    }
                    .padding(.bottom, AnaneoTheme.Spacing.xxl)
                }
                .scrollClipDisabled()
                .onChange(of: selection) { _, id in
                    guard let id else { return }
                    withAnimation(AnaneoMotion.settle(reduceMotion: reduceMotion)) {
                        proxy.scrollTo(id, anchor: .top)
                    }
                }
            }
        }
    }
}

/// One place: a tinted tile with its kind, the name and distance, what it accepts, and, once chosen, directions.
private struct PlaceCard: View {
    let place: Place
    let isSelected: Bool
    var onSelect: () -> Void

    private var color: Color { AnaneoTheme.color(for: place.kind) }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AnaneoTheme.Radius.card, style: .continuous)
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.md) {
                HStack(alignment: .top, spacing: AnaneoTheme.Spacing.md) {
                    Image(systemName: place.kind.systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(place.kind == .textile ? AnaneoTheme.forest : color)
                        .frame(width: 44, height: 44)
                        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.xs + 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(place.name)
                                .font(.headline)
                                .foregroundStyle(AnaneoTheme.ink)
                                .lineLimit(1)
                            Spacer(minLength: AnaneoTheme.Spacing.sm)
                            Text(Distance.label(miles: place.distanceMiles))
                                .numerals(.footnote)
                                .foregroundStyle(isSelected ? AnaneoTheme.progress : AnaneoTheme.smoke)
                        }
                        Text("\(place.kind.title) · \(place.address)")
                            .font(.footnote)
                            .foregroundStyle(AnaneoTheme.smoke)
                            .lineLimit(1)
                        if !place.accepts.isEmpty {
                            acceptsChips
                        }
                    }
                }
                if isSelected {
                    details
                }
            }
            .card(padding: AnaneoTheme.Spacing.md + 2)
            .overlay {
                if isSelected {
                    shape.strokeBorder(color, lineWidth: 2)
                }
            }
            .shadow(color: isSelected ? color.opacity(0.18) : .clear, radius: 13, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var acceptsChips: some View {
        // Wraps by scrolling, since a flow layout is more code than four chips deserve.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AnaneoTheme.Spacing.xs + 2) {
                ForEach(place.accepts) { category in
                    Text(category.title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AnaneoTheme.ink)
                        .padding(.horizontal, AnaneoTheme.Spacing.sm + 1)
                        .frame(minHeight: 24)
                        .background(AnaneoTheme.tile, in: Capsule())
                }
            }
        }
        .scrollClipDisabled()
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.sm + 2) {
            if let hours = place.hours {
                Label(hours, systemImage: "clock")
                    .font(.footnote)
                    .foregroundStyle(AnaneoTheme.smoke)
            }
            HStack(spacing: AnaneoTheme.Spacing.sm) {
                Button("Directions", systemImage: "arrow.triangle.turn.up.right.diamond") {
                    let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
                    item.name = place.name
                    item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault])
                }
                .buttonStyle(.pill(.primary, expanded: false))
                if let website = place.website, let url = URL(string: website) {
                    Link(destination: url) {
                        Label("Website", systemImage: "safari")
                    }
                    .buttonStyle(.pill(.secondary, expanded: false))
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

#Preview("Place sheet") {
    struct Demo: View {
        @State private var selection: Place.ID? = Place.samples.first?.id

        var body: some View {
            ZStack {
                AnaneoTheme.track.ignoresSafeArea()
                PlaceSheet(places: Place.samples, radiusMiles: 10, isLoading: false, errorMessage: nil, selection: $selection)
            }
        }
    }
    return Demo()
}
