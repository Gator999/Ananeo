import SwiftUI

@main
struct AnaneoApp: App {
    @State private var store = ItemStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
