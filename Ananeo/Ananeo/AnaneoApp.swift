import SwiftUI

@main
struct AnaneoApp: App {
    @State private var places = PlacesStore()
    @State private var listings = ListingService()
    @State private var pickups = PickupService()
    @State private var location = LocationService()
    @State private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(places)
                .environment(listings)
                .environment(pickups)
                .environment(location)
                .environment(auth)
                .task { auth.start() }
        }
    }
}
