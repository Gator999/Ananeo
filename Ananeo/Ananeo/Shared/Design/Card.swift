import SwiftUI

/// A card surface: 20 pt continuous corners, a soft ink shadow in light mode, and a hairline border in dark mode.
private struct CardModifier: ViewModifier {
    var padding: CGFloat?
    var radius: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .padding(.all, padding)
            .background {
                shape
                    .fill(AnaneoTheme.surface)
                    .shadow(color: colorScheme == .dark ? .clear : AnaneoTheme.shadow.opacity(0.08), radius: 12, y: 8)
            }
            .overlay {
                if colorScheme == .dark {
                    shape.strokeBorder(AnaneoTheme.hairline, lineWidth: 1)
                }
            }
    }
}

extension View {
    /// Puts the view on a card. Pass `padding: 0` for a card that is all photo.
    func card(padding: CGFloat? = AnaneoTheme.Spacing.lg, radius: CGFloat = AnaneoTheme.Radius.card) -> some View {
        modifier(CardModifier(padding: padding, radius: radius))
    }
}

/// A card with its content stacked top to bottom.
struct Card<Content: View>: View {
    var padding: CGFloat? = AnaneoTheme.Spacing.lg
    var spacing: CGFloat = AnaneoTheme.Spacing.md
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: padding)
    }
}

#Preview("Cards") {
    ScrollView {
        VStack(spacing: AnaneoTheme.Spacing.lg) {
            Card {
                Text("Oak bookshelf").font(.headline)
                Text("Solid wood, five shelves. Needs a pickup truck.")
                HStack { ModeChip(mode: .give); Chip(title: "1.9 mi", systemImage: "location") }
            }
            Card(padding: 0, spacing: 0) {
                AnaneoTheme.renewal.frame(height: 160)
                Text("A photo card, no padding").padding()
            }
            .clipShape(RoundedRectangle(cornerRadius: AnaneoTheme.Radius.card, style: .continuous))
        }
        .padding()
    }
    .background(AnaneoTheme.canvas)
}
