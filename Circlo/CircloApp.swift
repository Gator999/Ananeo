import SwiftUI

@main
struct CircloApp: App {
    @State private var store = ItemStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
