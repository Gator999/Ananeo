import SwiftUI

enum AppTab: Hashable {
    case browse, give, donate, impact
}

struct ContentView: View {
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
            Tab("Donate", systemImage: "mappin.and.ellipse", value: .donate) {
                DonationCentersView()
            }
            Tab("Impact", systemImage: "leaf", value: .impact) {
                ImpactView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(PlacesStore())
        .environment(ListingService())
        .environment(LocationService())
        .environment(AuthService())
}
