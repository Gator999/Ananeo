import SwiftUI

@main
struct AnaneoApp: App {
    @State private var places = PlaceService()
    @State private var listings = ListingService()
    @State private var pickups = PickupService()
    @State private var chat = ChatService()
    @State private var safety = SafetyService()
    @State private var terms = TermsService()
    @State private var location = LocationService()
    @State private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(places)
                .environment(listings)
                .environment(pickups)
                .environment(chat)
                .environment(safety)
                .environment(terms)
                .environment(location)
                .environment(auth)
                .task { auth.start() }
        }
    }
}
