import SwiftUI

@main
struct AnaneoApp: App {
    @State private var store = ItemStore()
    @State private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(auth)
                .task { auth.start() }
        }
    }
}
