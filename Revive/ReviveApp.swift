import SwiftUI

@main
struct ReviveApp: App {
    @State private var store = ItemStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
