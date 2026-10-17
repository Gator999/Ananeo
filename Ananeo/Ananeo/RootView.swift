import SwiftUI

/// Shows sign-in until there is a session, then the terms until they're accepted, then the main tabs.
struct RootView: View {
    @Environment(AuthService.self) private var auth
    @Environment(TermsService.self) private var terms
    @Environment(PickupService.self) private var pickups
    @Environment(ChatService.self) private var chat
    @Environment(SafetyService.self) private var safety

    var body: some View {
        Group {
            switch auth.state {
            case .loading:
                ProgressView()
            case .signedOut:
                SignInView()
            case .signedIn(let userID):
                signedIn(userID)
            }
        }
        .animation(.default, value: auth.state)
        // One account's pickups, messages, blocks, and terms status must never carry over to the next.
        .onChange(of: auth.state) {
            pickups.reset()
            chat.reset()
            safety.reset()
            terms.reset()
        }
    }

    @ViewBuilder
    private func signedIn(_ userID: UUID) -> some View {
        switch terms.status {
        case .accepted:
            ContentView()
        case .needed:
            TermsAcceptanceView(userID: userID)
        case .checking:
            ProgressView()
                .task { await terms.check(userID: userID) }
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't Load Your Account", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { terms.reset() }
            }
        }
    }
}
