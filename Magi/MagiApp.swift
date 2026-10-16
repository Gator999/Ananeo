import SwiftUI

@main
struct MagiApp: App {
    @State private var store = ItemStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
