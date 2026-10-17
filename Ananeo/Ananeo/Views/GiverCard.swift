import SwiftUI

/// Who is giving the item: their initial on the gradient, their name, and how many handoffs they have completed.
struct GiverCard: View {
    @Environment(ListingService.self) private var listings
    let userID: UUID

    @State private var profile: PublicProfile?
    @State private var hasLoaded = false

    var body: some View {
        let shown = profile ?? .placeholder
        HStack(spacing: AnaneoTheme.Spacing.md) {
            Text(shown.initial)
                .numerals(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(AnaneoTheme.renewalButton, in: Circle())
                .overlay { Circle().strokeBorder(AnaneoTheme.mint, lineWidth: 2).padding(-3) }
            VStack(alignment: .leading, spacing: 2) {
                Text(shown.displayName)
                    .font(.headline)
                    .foregroundStyle(AnaneoTheme.ink)
                keptMoving(shown.itemsKeptMoving)
                    .font(.footnote)
                    .foregroundStyle(AnaneoTheme.smoke)
            }
            Spacer(minLength: 0)
        }
        .card(padding: AnaneoTheme.Spacing.md)
        .skeleton(!hasLoaded)
        .accessibilityElement(children: .combine)
        .task(id: userID) {
            profile = try? await listings.publicProfile(userID)
            hasLoaded = true
        }
    }

    private func keptMoving(_ count: Int) -> Text {
        if count == 0 {
            return Text("New to Ananeo")
        }
        return Text("\(count)").bold().foregroundStyle(AnaneoTheme.leaf)
            + Text(count == 1 ? " item kept moving" : " items kept moving")
    }
}

#Preview("Giver card") {
    GiverCard(userID: UUID())
        .padding()
        .background(AnaneoTheme.canvas)
        .environment(ListingService())
}
