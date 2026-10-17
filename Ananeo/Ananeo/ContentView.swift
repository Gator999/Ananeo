import SwiftUI

enum AppTab: Hashable {
    case browse, give, pickups, donate, impact
}

struct ContentView: View {
    @Environment(PickupService.self) private var pickups
    @Environment(ChatService.self) private var chat
    @Environment(\.scenePhase) private var scenePhase
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
            .badge(pickups.needsYouCount)
            Tab("Donate", systemImage: "mappin.and.ellipse", value: .donate) {
                DonationCentersView()
            }
            Tab("Impact", systemImage: "leaf", value: .impact) {
                ImpactView()
            }
        }
        // One Realtime connection for the signed-in session. It ends when this view goes away at sign-out.
        .task { await chat.listen() }
        // Keep the tab badge right: at launch, when messages or handoffs change, and on return to the app.
        .task(id: chat.revision) { try? await pickups.refresh() }
        .onChange(of: scenePhase) {
            if scenePhase == .active { Task { try? await pickups.refresh() } }
        }
    }
}

#Preview {
    ContentView()
        .environment(PlacesStore())
        .environment(ListingService())
        .environment(PickupService.preview([.preview]))
        .environment(ChatService.preview([]))
        .environment(LocationService())
        .environment(AuthService())
}
