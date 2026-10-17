import SwiftUI

/// One listing in the Browse grid: the photo with its mode chip and distance, then the title.
struct ListingCard: View {
    @Environment(ListingService.self) private var listings
    let listing: Listing

    var body: some View {
        VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.sm) {
            photo
            VStack(alignment: .leading, spacing: 2) {
                Text(listing.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AnaneoTheme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.footnote.weight(needsWork ? .semibold : .regular))
                    .foregroundStyle(needsWork ? AnaneoTheme.clay : AnaneoTheme.smoke)
                    .lineLimit(1)
            }
            .padding(.horizontal, AnaneoTheme.Spacing.xs)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(listing.title), \(listing.mode.title), \(subtitle)")
    }

    private var photo: some View {
        let shape = RoundedRectangle(cornerRadius: AnaneoTheme.Radius.card, style: .continuous)
        return Color.clear
            .aspectRatio(4 / 5, contentMode: .fit)
            .overlay {
                ListingPhoto(urls: listing.photos.first.map(listings.gridURLs) ?? [], placeholder: listing.category.systemImage)
            }
            .clipShape(shape)
            .card(padding: 0)
            .overlay(alignment: .topLeading) {
                ModeChip(mode: listing.mode)
                    .padding(AnaneoTheme.Spacing.sm + 2)
            }
            .overlay(alignment: .bottomLeading) {
                if let miles = listing.distanceMiles {
                    Text(Distance.label(miles: miles))
                        .numerals(.caption)
                        .foregroundStyle(AnaneoTheme.ink)
                        .padding(.horizontal, AnaneoTheme.Spacing.sm + 2)
                        .frame(height: AnaneoTheme.Size.modeChip)
                        .glass()
                        .padding(AnaneoTheme.Spacing.sm + 2)
                }
            }
    }

    private var needsWork: Bool {
        listing.condition == .needsRepair || listing.condition == .forParts
    }

    private var subtitle: String {
        if let wants = listing.wants, !wants.isEmpty {
            return "\(listing.condition.title) · wants \(wants)"
        }
        return "\(listing.condition.title) · \(listing.createdAt.formatted(.relative(presentation: .named)))"
    }
}

#Preview("Listing cards") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AnaneoTheme.Spacing.lg - 2) {
            ListingCard(listing: .preview)
            ListingCard(listing: Listing(
                id: UUID(), ownerID: UUID(), title: "Desk lamp", details: "",
                category: .household, condition: .needsRepair, mode: .parts, status: .available,
                wants: nil, estKg: 1.5, photos: [], createdAt: .now, distanceKm: 3.9, latitude: nil, longitude: nil
            ))
            ListingCard(listing: Listing(
                id: UUID(), ownerID: UUID(), title: "Road bike, 56 cm", details: "",
                category: .other, condition: .worn, mode: .swap, status: .available,
                wants: "a bike rack", estKg: 10, photos: [], createdAt: .now, distanceKm: 1, latitude: nil, longitude: nil
            ))
        }
        .padding()
    }
    .background(AnaneoTheme.canvas)
    .environment(ListingService())
}
