import SwiftUI

enum AppTab: Hashable {
    case browse, give, pickups, donate, impact
}

struct ContentView: View {
    @Environment(PickupService.self) private var pickups
    @Environment(ChatService.self) private var chat
    @State private var selection: AppTab = .browse

    var body: some View {
        TabView(selection: $selection) {
            Tab("Browse", systemImage: "magnifyingglass", value: .browse) {
                BrowseView()
            }
            Tab("Give", systemImage: "plus.circle", value: .give) {
                // After posting, show the feed so the new item is visible right away.
                ListItemView(onPosted: { selection = .browse })
            }
            Tab("Pickups", systemImage: "arrow.left.arrow.right", value: .pickups) {
                PickupsView()
            }
            .badge(pickups.needsYouCount + chat.unreadCount(in: pickups.all))
            Tab("Donate", systemImage: "mappin.and.ellipse", value: .donate) {
                DonationCentersView()
            }
            Tab("Impact", systemImage: "leaf", value: .impact) {
                ImpactView()
            }
        }
        // Load pickups at launch so the tab badge is right before the tab is opened.
        .task { try? await pickups.refresh() }
        // Keep unread counts live while signed in. Stops when this view goes away at sign-out.
        .task { await chat.watchInbox() }
    }
}

#Preview {
    ContentView()
        .environment(PlacesStore())
        .environment(ListingService())
        .environment(PickupService.preview([.preview]))
        .environment(ChatService.preview())
        .environment(LocationService())
        .environment(AuthService())
}
