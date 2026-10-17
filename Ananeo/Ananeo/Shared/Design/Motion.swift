import SwiftUI

/// Named animations for the signature moves. Each takes the Reduce Motion setting and returns `nil` when it is on,
/// so a view can write `.animation(AnaneoMotion.loopFill(reduceMotion: reduceMotion), value: progress)`.
enum AnaneoMotion {
    /// The loop ring and stage connectors filling.
    static func loopFill(reduceMotion: Bool = false) -> Animation? {
        reduceMotion ? nil : .spring(duration: 0.6, bounce: 0.2)
    }

    /// A pill pressing down to 0.97.
    static func press(reduceMotion: Bool = false) -> Animation? {
        reduceMotion ? nil : .spring(duration: 0.25, bounce: 0.3)
    }

    /// Chips and cards changing state.
    static func settle(reduceMotion: Bool = false) -> Animation? {
        reduceMotion ? nil : .smooth(duration: 0.3)
    }

    /// Numbers rolling. Pair with `.contentTransition(.numericText())` on the text.
    static func roll(reduceMotion: Bool = false) -> Animation? {
        reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.1)
    }
}

/// Cards fade and scale in as they scroll into view. Still under Reduce Motion.
private struct EaseInOnScroll: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.scrollTransition(.animated) { view, phase in
            view
                .opacity(phase.isIdentity || reduceMotion ? 1 : 0.4)
                .scaleEffect(phase.isIdentity || reduceMotion ? 1 : 0.94)
        }
    }
}

extension View {
    /// Fades and scales the view in as it scrolls into view. For cards in a feed.
    func easeInOnScroll() -> some View {
        modifier(EaseInOnScroll())
    }
}

#Preview("Ease in on scroll") {
    ScrollView {
        LazyVStack(spacing: AnaneoTheme.Spacing.md) {
            ForEach(0..<20) { index in
                RoundedRectangle(cornerRadius: AnaneoTheme.Radius.card, style: .continuous)
                    .fill(index.isMultiple(of: 2) ? AnaneoTheme.leaf : AnaneoTheme.forest)
                    .frame(height: 120)
                    .easeInOnScroll()
            }
        }
        .padding()
    }
    .background(AnaneoTheme.canvas)
}
