import SwiftUI

@main
struct ReuseApp: App {
    @State private var store = ItemStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
