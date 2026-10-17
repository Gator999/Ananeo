import MapKit
import SwiftUI

/// The map behind the Places tab: a pin per place, colored by kind, with the chosen one larger and labeled.
struct PlacesMap: View {
    let places: [Place]
    @Binding var selection: Place.ID?
    @Binding var position: MapCameraPosition

    var body: some View {
        Map(position: $position, selection: $selection) {
            UserAnnotation()
            ForEach(places) { place in
                Annotation(place.name, coordinate: place.coordinate, anchor: .bottom) {
                    PlacePin(place: place, isSelected: place.id == selection)
                }
                .tag(place.id)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .annotationTitles(.hidden)
        .mapControlVisibility(.hidden)
    }
}

/// A colored dot with the kind's icon on a short stem. The chosen one grows and shows its name and distance.
private struct PlacePin: View {
    let place: Place
    let isSelected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var color: Color { AnaneoTheme.color(for: place.kind) }

    var body: some View {
        VStack(spacing: 0) {
            if isSelected {
                HStack(spacing: AnaneoTheme.Spacing.xs + 2) {
                    Text(place.name)
                    Text("·")
                    Text(Distance.label(miles: place.distanceMiles)).monospacedDigit()
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(AnaneoTheme.canvas)
                .padding(.horizontal, AnaneoTheme.Spacing.md)
                .frame(minHeight: 30)
                .background(AnaneoTheme.ink, in: Capsule())
                .shadow(color: AnaneoTheme.shadow.opacity(0.25), radius: 9, y: 8)
                .padding(.bottom, AnaneoTheme.Spacing.xs + 2)
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
            }
            Image(systemName: place.kind.systemImage)
                .font(isSelected ? .subheadline.weight(.bold) : .caption.weight(.bold))
                .foregroundStyle(place.kind == .textile ? AnaneoTheme.forest : .white)
                .frame(width: isSelected ? 40 : 30, height: isSelected ? 40 : 30)
                .background(color, in: Circle())
                .overlay { Circle().strokeBorder(.white, lineWidth: isSelected ? 4 : 3) }
                .shadow(color: isSelected ? color.opacity(0.4) : AnaneoTheme.shadow.opacity(0.25), radius: 9, y: 8)
            Capsule()
                .fill(.white)
                .frame(width: 3, height: isSelected ? 10 : 8)
        }
        .animation(AnaneoMotion.settle(reduceMotion: reduceMotion), value: isSelected)
        .accessibilityLabel("\(place.name), \(place.kind.title), \(Distance.label(miles: place.distanceMiles))")
    }
}

#Preview("Places map") {
    struct Demo: View {
        @State private var selection: Place.ID? = Place.samples.first?.id
        @State private var position: MapCameraPosition = .region(
            MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 40.678, longitude: -73.944), latitudinalMeters: 6000, longitudinalMeters: 6000)
        )

        var body: some View {
            PlacesMap(places: Place.samples, selection: $selection, position: $position)
                .ignoresSafeArea()
        }
    }
    return Demo()
}
