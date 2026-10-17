import SwiftUI

/// The one primary action on a screen: a 56 pt pill.
///
/// Primary fills with the Renewal gradient, secondary is tinted glass, and `glass` sits on the gradient itself.
/// Pressing scales the pill to 0.97 with a light haptic.
struct PillButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        /// Translucent white with a hairline, for buttons on the gradient or on Forest.
        case glass
    }

    var kind: Kind = .primary
    /// Fills the available width. Pass `false` for a pill that hugs its label, like "Message" beside "Ask for it".
    var isExpanded = true

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AnaneoTheme.Typography.button)
            .foregroundStyle(foreground(for: configuration.role))
            .padding(.horizontal, AnaneoTheme.Spacing.xl)
            .frame(maxWidth: isExpanded ? CGFloat.infinity : nil)
            .frame(minHeight: AnaneoTheme.Size.pillButton)
            .background(background, in: Capsule())
            .overlay { highlight }
            .shadow(color: shadow, radius: 12, y: 6)
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(AnaneoMotion.press(reduceMotion: reduceMotion), value: configuration.isPressed)
            .sensoryFeedback(trigger: configuration.isPressed) { _, isPressed in
                isPressed ? .impact(weight: .light) : nil
            }
    }

    /// Destructive secondary pills, like "Remove Listing", read in red.
    private func foreground(for role: ButtonRole?) -> Color {
        switch kind {
        case .primary, .glass: .white
        case .secondary: role == .destructive ? .red : AnaneoTheme.ink
        }
    }

    private var background: AnyShapeStyle {
        switch kind {
        case .primary: AnyShapeStyle(AnaneoTheme.renewalButton)
        case .secondary: AnyShapeStyle(AnaneoTheme.ink.opacity(0.08))
        case .glass: AnyShapeStyle(Color.white.opacity(0.14))
        }
    }

    private var shadow: Color {
        kind == .primary ? AnaneoTheme.leaf.opacity(0.32) : .clear
    }

    /// A faint light along the top edge of the primary pill, and a hairline around the glass one.
    @ViewBuilder
    private var highlight: some View {
        switch kind {
        case .primary:
            Capsule()
                .fill(LinearGradient(colors: [.white.opacity(0.28), .clear], startPoint: .top, endPoint: .center))
                .allowsHitTesting(false)
        case .glass:
            Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1)
        case .secondary:
            EmptyView()
        }
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    /// The gradient pill that fills the width.
    static var pill: PillButtonStyle { PillButtonStyle() }

    static func pill(_ kind: PillButtonStyle.Kind, expanded: Bool = true) -> PillButtonStyle {
        PillButtonStyle(kind: kind, isExpanded: expanded)
    }
}

#Preview("Pill buttons") {
    VStack(spacing: AnaneoTheme.Spacing.lg) {
        HStack(spacing: AnaneoTheme.Spacing.md) {
            Button("Ask for it", systemImage: "hand.raised") {}
                .buttonStyle(.pill)
            Button("Message") {}
                .buttonStyle(.pill(.secondary, expanded: false))
        }
        Button("Post Item") {}
            .buttonStyle(.pill)
            .disabled(true)
        Button("Continue", systemImage: "arrow.right") {}
            .buttonStyle(.pill(.glass))
            .padding()
            .background(AnaneoTheme.renewal, in: RoundedRectangle(cornerRadius: AnaneoTheme.Radius.card, style: .continuous))
    }
    .padding()
    .background(AnaneoTheme.canvas)
}
