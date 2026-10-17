import MapKit
import SwiftUI

/// One listing: a full-bleed photo hero, the facts, who is giving it, and one pill to ask for it.
struct ListingDetailView: View {
    @Environment(ListingService.self) private var listings
    @Environment(PickupService.self) private var pickups
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    let listing: Listing

    @State private var confirmingRemove = false
    @State private var isRemoving = false
    @State private var isRequesting = false
    @State private var errorMessage: String?
    /// The toolbar turns solid with the title once the hero has scrolled away.
    @State private var isPastHero = false

    private let heroHeight: CGFloat = 430

    private var isMine: Bool {
        if case .signedIn(let userID) = auth.state { userID == listing.ownerID } else { false }
    }

    private var hasRequested: Bool {
        pickups.pickup(for: listing.id)?.isGiver == false
    }

    /// For the owner: how many people have asked for this item.
    private var requestCount: Int {
        isMine ? pickups.pickup(for: listing.id)?.requests.count ?? 0 : 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.lg + 2) {
                hero
                VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.lg + 2) {
                    facts
                    if !listing.details.isEmpty {
                        Text(listing.details)
                            .foregroundStyle(AnaneoTheme.ink)
                    }
                    GiverCard(userID: listing.ownerID)
                    areaMap
                    safetyTip
                }
                .padding(.horizontal, AnaneoTheme.Spacing.xl)
            }
            .padding(.bottom, AnaneoTheme.Spacing.xl)
        }
        .background(AnaneoTheme.canvas)
        .ignoresSafeArea(edges: .top)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > heroHeight - 120
        } action: { _, isPast in
            isPastHero = isPast
        }
        .safeAreaInset(edge: .bottom) { actionBar }
        .navigationTitle(isPastHero ? listing.title : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(isPastHero ? .visible : .hidden, for: .navigationBar)
        .toolbarColorScheme(isPastHero ? nil : .dark, for: .navigationBar)
        .confirmationDialog("Remove this listing?", isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button("Remove Listing", role: .destructive) { Task { await remove() } }
        } message: {
            Text("It will no longer be visible to anyone.")
        }
    }

    // MARK: - Hero

    private var hero: some View {
        PhotoPager(urls: listing.photos.compactMap(listings.photoURL), placeholder: listing.category.systemImage)
            .frame(height: heroHeight)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.sm + 2) {
                    HStack(spacing: AnaneoTheme.Spacing.sm) {
                        ModeChip(mode: listing.mode)
                        Chip(title: listing.condition.title)
                    }
                    Text(listing.title)
                        .displayTitle()
                        .foregroundStyle(.white)
                    Text(meta)
                        .numerals(.subheadline)
                        .foregroundStyle(AnaneoTheme.mint)
                }
                // Chips and text sit on the dark scrim, so they take the dark look whatever the system setting.
                .environment(\.colorScheme, .dark)
                .padding(.horizontal, AnaneoTheme.Spacing.xl)
                .padding(.bottom, AnaneoTheme.Spacing.xl + 2)
            }
    }

    private var meta: String {
        var parts: [String] = []
        if let miles = listing.distanceMiles {
            parts.append(Distance.label(miles: miles))
        }
        parts.append("Listed \(listing.createdAt.formatted(.relative(presentation: .named)))")
        return parts.joined(separator: " · ")
    }

    // MARK: - Facts

    private var facts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AnaneoTheme.Spacing.sm) {
                Chip(title: listing.category.title, systemImage: listing.category.systemImage)
                TintChip(
                    title: "~\(listing.estKg.formatted(.number.precision(.fractionLength(0)))) kg kept from landfill",
                    systemImage: "leaf",
                    tint: AnaneoTheme.leaf
                )
                if let wants = listing.wants, !wants.isEmpty {
                    TintChip(title: "Wants \(wants)", systemImage: "arrow.left.arrow.right", tint: AnaneoTheme.sun)
                }
            }
        }
        .scrollClipDisabled()
    }

    @ViewBuilder
    private var areaMap: some View {
        if let coordinate = listing.coordinate {
            let shape = RoundedRectangle(cornerRadius: AnaneoTheme.Radius.card - 2, style: .continuous)
            Map(
                initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 1800, longitudinalMeters: 1800)),
                interactionModes: []
            ) {
                MapCircle(center: coordinate, radius: 400)
                    .foregroundStyle(AnaneoTheme.leaf.opacity(0.22))
                    .stroke(AnaneoTheme.leaf, lineWidth: 2)
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(height: 112)
            .clipShape(shape)
            .overlay(alignment: .bottomLeading) {
                Label("Approximate area, within about ¼ mile", systemImage: "mappin.and.ellipse")
                    .font(AnaneoTheme.Typography.modeChip)
                    .foregroundStyle(AnaneoTheme.ink)
                    .padding(.horizontal, AnaneoTheme.Spacing.md - 2)
                    .frame(height: AnaneoTheme.Size.modeChip)
                    .glass()
                    .padding(AnaneoTheme.Spacing.md)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Map of the approximate pickup area")
        }
    }

    private var safetyTip: some View {
        HStack(alignment: .top, spacing: AnaneoTheme.Spacing.md) {
            Image(systemName: "checkmark.shield")
                .font(.title3)
                .foregroundStyle(AnaneoTheme.sky)
            Text("Meet in a public place. Share your exact address only in chat, once you've chosen each other.")
                .font(.footnote)
                .foregroundStyle(AnaneoTheme.ink)
        }
        .padding(AnaneoTheme.Spacing.md + 2)
        .background(AnaneoTheme.sky.opacity(0.1), in: RoundedRectangle(cornerRadius: AnaneoTheme.Radius.card - 2, style: .continuous))
    }

    // MARK: - Action bar

    private var actionBar: some View {
        VStack(spacing: AnaneoTheme.Spacing.sm + 2) {
            if isMine {
                Button("Remove Listing", systemImage: "trash", role: .destructive) { confirmingRemove = true }
                    .buttonStyle(.pill(.secondary))
                    .disabled(isRemoving)
            } else {
                Button {
                    Task { await request() }
                } label: {
                    Label(hasRequested ? "Requested" : "Ask for it", systemImage: hasRequested ? "checkmark.circle.fill" : "hand.raised")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.pill(hasRequested ? .secondary : .primary))
                .disabled(isRequesting)
                .animation(AnaneoMotion.settle(), value: hasRequested)
                .sensoryFeedback(.success, trigger: hasRequested)
            }
            Text(footer)
                .font(.caption)
                .foregroundStyle(errorMessage == nil ? AnaneoTheme.smoke : .red)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, AnaneoTheme.Spacing.xl)
        .padding(.top, AnaneoTheme.Spacing.md)
        .padding(.bottom, AnaneoTheme.Spacing.sm)
        .background(.bar)
    }

    private var footer: String {
        if let errorMessage { return errorMessage }
        if requestCount > 0 {
            return requestCount == 1
                ? "1 person asked for this. Choose who gets it in Pickups."
                : "\(requestCount) people asked for this. Choose who gets it in Pickups."
        }
        if isMine { return "Nobody has asked yet. It shows to people within a few miles." }
        if hasRequested { return "Follow along in Pickups. If the giver chooses you, you'll both confirm the handoff there." }
        return "The giver chooses who gets it from everyone who asks."
    }

    // MARK: - Actions

    private func request() async {
        guard !hasRequested else { return }
        errorMessage = nil
        isRequesting = true
        defer { isRequesting = false }
        do {
            try await pickups.request(listing)
        } catch {
            errorMessage = "Couldn't send your request: \(error.localizedDescription)"
        }
    }

    private func remove() async {
        isRemoving = true
        defer { isRemoving = false }
        do {
            try await listings.remove(listing)
            dismiss()
        } catch {
            errorMessage = "Couldn't remove: \(error.localizedDescription)"
        }
    }
}

/// A chip tinted with one of the brand colors, for facts like the weight kept from landfill.
private struct TintChip: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(AnaneoTheme.Typography.chip)
            .foregroundStyle(AnaneoTheme.forest)
            .padding(.horizontal, AnaneoTheme.Spacing.md)
            .frame(height: AnaneoTheme.Size.chip)
            .background(tint.opacity(0.15), in: Capsule())
    }
}

#Preview {
    NavigationStack {
        ListingDetailView(listing: .preview)
    }
    .environment(ListingService())
    .environment(PickupService())
    .environment(AuthService())
}
