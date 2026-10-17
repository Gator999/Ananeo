import SwiftUI

/// Everyone's totals on the Renewal gradient, with the loop mark. Browse and Impact both show it.
struct CommunityCard: View {
    let community: CommunityImpact

    var body: some View {
        HStack(spacing: AnaneoTheme.Spacing.md + 2) {
            LoopMark.onGradient
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Everyone on Ananeo")
                    .sectionLabel(.white.opacity(0.85))
                totals
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AnaneoTheme.Spacing.lg)
        .padding(.vertical, AnaneoTheme.Spacing.md + 2)
        .background(AnaneoTheme.renewal, in: RoundedRectangle(cornerRadius: AnaneoTheme.Radius.card, style: .continuous))
        .shadow(color: AnaneoTheme.forest.opacity(0.28), radius: 14, y: 10)
        .accessibilityElement(children: .combine)
    }

    private var totals: Text {
        Text(community.itemsKeptMoving, format: .number).font(AnaneoTheme.Typography.numerals(.title3))
            + Text(" items kept moving · ")
            + Text(community.kgDiverted, format: .number.precision(.fractionLength(0))).font(AnaneoTheme.Typography.numerals(.title3))
            + Text(" kg")
    }
}

#Preview("Community card") {
    CommunityCard(community: CommunityImpact(itemsKeptMoving: 1284, kgDiverted: 6120))
        .padding()
        .background(AnaneoTheme.canvas)
}
