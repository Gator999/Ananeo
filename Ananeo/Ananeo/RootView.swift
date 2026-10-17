import SwiftUI

/// Shows sign-in until there is a session, then the main tabs.
struct RootView: View {
    @Environment(AuthService.self) private var auth

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
    }
}
