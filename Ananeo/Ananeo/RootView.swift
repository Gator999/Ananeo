import SwiftUI

/// Shows sign-in until there is a session, then the main tabs.
struct RootView: View {
    @Environment(AuthService.self) private var auth
    @Environment(PickupService.self) private var pickups
    @Environment(ChatService.self) private var chat

    var body: some View {
        Group {
            switch auth.state {
            case .loading:
                ProgressView()
            case .signedOut:
                SignInView()
            case .signedIn:
                ContentView()
            }
        }
        .animation(.default, value: auth.state)
        // One account's pickups and messages must never show for the next.
        .onChange(of: auth.state) {
            pickups.reset()
            chat.reset()
        }
    }
}
