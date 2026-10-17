import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case browse, pickups, places, impact

    var title: String {
        switch self {
        case .browse: "Browse"
        case .pickups: "Pickups"
        case .places: "Places"
        case .impact: "Impact"
        }
    }

    var systemImage: String {
        switch self {
        case .browse: "safari"
        case .pickups: "arrow.left.arrow.right"
        case .places: "mappin.and.ellipse"
        case .impact: "leaf"
        }
    }
}

/// The four tabs under a floating glass bar, the Give button, and the Give flow as a full-screen sheet.
/// Every tab stays alive, as in a TabView, so switching back keeps scroll position and loaded data.
struct ContentView: View {
    @Environment(PickupService.self) private var pickups
    @Environment(ChatService.self) private var chat
    @Environment(SafetyService.self) private var safety
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selection: AppTab = .browse
    @State private var isGiving = false
    @State private var isBarHidden = false
    @State private var showsPostedToast = false

    var body: some View {
        ZStack {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabContent(tab)
                    .opacity(selection == tab ? 1 : 0)
                    .allowsHitTesting(selection == tab)
                    .accessibilityHidden(selection != tab)
                    // Only the visible tab decides whether the bar shows.
                    .transformPreference(FloatingTabBarHiddenKey.self) { hidden in
                        if selection != tab { hidden = false }
                    }
            }
        }
        .onPreferenceChange(FloatingTabBarHiddenKey.self) { isBarHidden = $0 }
        .safeAreaInset(edge: .bottom) {
            if !isBarHidden {
                FloatingTabBar(
                    selection: $selection,
                    pickupsBadge: pickups.needsYouCount + chat.unreadCount(in: pickups.all)
                ) {
                    isGiving = true
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(AnaneoMotion.settle(reduceMotion: reduceMotion), value: isBarHidden)
        .overlay(alignment: .top) {
            if showsPostedToast {
                PostedToast()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sensoryFeedback(trigger: showsPostedToast) { _, shown in shown ? .success : nil }
        .fullScreenCover(isPresented: $isGiving) {
            // After posting, show the feed so the new item is visible right away.
            GiveFlow {
                isGiving = false
                selection = .browse
                showPostedToast()
            }
        }
        .task { try? await safety.refresh() }
        // Load pickups at launch so the tab badge is right before the tab is opened, and again when
        // blocks change, since blocking ends pickups in progress.
        .task(id: safety.revision) { try? await pickups.refresh() }
        // Keep unread counts live while signed in. Stops when this view goes away at sign-out.
        .task { await chat.watchInbox() }
    }

    @ViewBuilder
    private func tabContent(_ tab: AppTab) -> some View {
        switch tab {
        case .browse: BrowseView()
        case .pickups: PickupsView()
        case .places: PlacesView()
        case .impact: ImpactView()
        }
    }

    private func showPostedToast() {
        withAnimation(AnaneoMotion.settle(reduceMotion: reduceMotion)) { showsPostedToast = true }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(AnaneoMotion.settle(reduceMotion: reduceMotion)) { showsPostedToast = false }
        }
    }
}

/// "It's live near you", shown for a moment after a post.
private struct PostedToast: View {
    var body: some View {
        Label("It's live near you", systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(AnaneoTheme.ink)
            .padding(.horizontal, AnaneoTheme.Spacing.lg)
            .frame(minHeight: 44)
            .glass()
            .shadow(color: AnaneoTheme.shadow.opacity(0.16), radius: 12, y: 8)
            .padding(.top, AnaneoTheme.Spacing.sm)
    }
}

#Preview {
    ContentView()
        .environment(PlaceService())
        .environment(ListingService())
        .environment(PickupService.preview([.preview]))
        .environment(ChatService.preview())
        .environment(SafetyService())
        .environment(LocationService())
        .environment(AuthService())
}
