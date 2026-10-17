import SwiftUI

/// Personal and community totals, counted only from handoffs both sides confirmed. Counters roll on every open.
struct ImpactView: View {
    @Environment(ListingService.self) private var listings
    @Environment(PickupService.self) private var pickups
    @Environment(AuthService.self) private var auth
    @Environment(SafetyService.self) private var safety
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var mine = Impact()
    @State private var community: CommunityImpact?
    @State private var errorMessage: String?
    @State private var confirmingDelete = false
    @State private var shareImage: Image?
    @State private var showingBlocked = false
    @State private var showingModeration = false
    @State private var showingTerms = false

    private var handoffs: Int { mine.itemsGiven + mine.itemsReceived }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.xl) {
                    header
                    hero
                    tiles
                    if let community {
                        CommunityCard(community: community)
                    }
                    shareRow
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                    } else if handoffs == 0 {
                        Text("Your totals grow each time a handoff is confirmed by both people.")
                            .font(.footnote)
                            .foregroundStyle(AnaneoTheme.smoke)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, AnaneoTheme.Spacing.xl)
                .padding(.bottom, AnaneoTheme.Spacing.xxl)
            }
            .background(backdrop)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await load() }
            .sheet(isPresented: $showingBlocked) { BlockedPeopleView() }
            .sheet(isPresented: $showingModeration) { ModerationView() }
            .sheet(isPresented: $showingTerms) { TermsSheet() }
            .task(id: [listings.revision, pickups.revision]) { await load() }
            .confirmationDialog("Delete your account?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete Account", role: .destructive) {
                    Task { await auth.deleteAccount() }
                }
            } message: {
                Text("Your listings, messages, and impact history will be permanently removed.")
            }
        }
    }

    /// A soft Leaf glow behind the ring.
    private var backdrop: some View {
        ZStack {
            AnaneoTheme.canvas
            RadialGradient(colors: [AnaneoTheme.leaf.opacity(0.22), .clear], center: UnitPoint(x: 0.5, y: 0.22), startRadius: 0, endRadius: 320)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.xs + 2) {
                Text("Confirmed by both people").sectionLabel()
                Text("Your impact")
                    .displayTitle()
                    .foregroundStyle(AnaneoTheme.ink)
            }
            .accessibilityAddTraits(.isHeader)
            Spacer()
            Menu {
                Button("Blocked People", systemImage: "hand.raised") { showingBlocked = true }
                if safety.isModerator {
                    Button("Moderation", systemImage: "checkmark.shield") { showingModeration = true }
                }
                Button("Terms of Use", systemImage: "doc.text") { showingTerms = true }
                Divider()
                Button("Sign Out") {
                    Task { await auth.signOut() }
                }
                Button("Delete Account", role: .destructive) {
                    confirmingDelete = true
                }
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.title3)
                    .foregroundStyle(AnaneoTheme.ink)
                    .frame(width: 42, height: 42)
                    .glass()
            }
            .accessibilityLabel("Account")
        }
        .padding(.top, AnaneoTheme.Spacing.sm)
    }

    private var hero: some View {
        VStack(spacing: AnaneoTheme.Spacing.lg) {
            ImpactRing(pounds: mine.poundsDiverted)
                .frame(width: 236)
            HStack(spacing: AnaneoTheme.Spacing.sm) {
                LoopMark().frame(width: 16, height: 16)
                (Text(handoffs, format: .number).font(AnaneoTheme.Typography.numerals(.subheadline))
                    + Text(handoffs == 1 ? " handoff confirmed" : " handoffs confirmed"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AnaneoTheme.ink)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, AnaneoTheme.Spacing.lg - 2)
            .frame(minHeight: 32)
            .glass()
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AnaneoTheme.Spacing.sm)
    }

    private var tiles: some View {
        HStack(spacing: AnaneoTheme.Spacing.md) {
            StatTile(count: mine.itemsGiven, label: "Items given")
            StatTile(count: mine.itemsReceived, label: "Items received")
        }
    }

    private var shareRow: some View {
        HStack(spacing: AnaneoTheme.Spacing.md + 2) {
            ShareCard(impact: mine)
                .scaleEffect(54 / ShareCard.size.width, anchor: .topLeading)
                .frame(width: 54, height: 54 * ShareCard.size.height / ShareCard.size.width)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: AnaneoTheme.leaf.opacity(0.3), radius: 9, y: 8)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Share your impact")
                    .font(.headline)
                    .foregroundStyle(AnaneoTheme.ink)
                Text("A story-sized card with your totals and the loop.")
                    .font(.caption)
                    .foregroundStyle(AnaneoTheme.smoke)
            }
            Spacer(minLength: 0)
            if let shareImage {
                ShareLink(item: shareImage, preview: SharePreview("Your impact on Ananeo", image: shareImage)) {
                    Text("Share")
                }
                .buttonStyle(.pill(.secondary, expanded: false))
            }
        }
        .card(padding: AnaneoTheme.Spacing.md + 2)
    }

    private func load() async {
        do {
            async let mineResult = listings.myImpact()
            async let communityResult = listings.communityImpact()
            let (newMine, newCommunity) = try await (mineResult, communityResult)
            withAnimation(AnaneoMotion.roll(reduceMotion: reduceMotion)) {
                mine = newMine
                community = newCommunity
            }
            errorMessage = nil
            shareImage = ShareCard.render(newMine)
        } catch is CancellationError {
        } catch {
            errorMessage = "Couldn't load totals: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ImpactView()
        .environment(ListingService())
        .environment(PickupService())
        .environment(AuthService())
        .environment(SafetyService())
}
