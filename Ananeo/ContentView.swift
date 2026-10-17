import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Browse", systemImage: "magnifyingglass") {
                BrowseView()
            }
            Tab("Give", systemImage: "plus.circle") {
                ListItemView()
            }
            Tab("Donate", systemImage: "mappin.and.ellipse") {
                DonationCentersView()
            }
            Tab("Impact", systemImage: "leaf") {
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
