import SwiftUI

/// Design tokens for the "Keep It Moving" look.
///
/// Colors come from the asset catalog's Brand folder, so each one carries its own dark-mode variant.
/// Phase 0 of the redesign adds these without changing any screen. The app's tint is still `AccentColor`;
/// Phase 1 switches it to Leaf when Browse takes the new look.
enum AnaneoTheme {
    // MARK: - Renewal palette, the same in light and dark

    /// Hero backgrounds, dark surfaces, and the start of the gradient.
    static let forest = Color("BrandForest")
    /// Primary actions, Free listings, and selected states.
    static let leaf = Color("BrandLeaf")
    /// The end of the gradient and glows on dark. Never carries text.
    static let mint = Color("BrandMint")
    /// The loop's second arrow and celebration particles only.
    static let spark = Color("BrandSpark")
    /// Swap listings and "wants in return".
    static let sun = Color("BrandSun")
    /// Needs repair, For parts, and the Fix-it feed.
    static let clay = Color("BrandClay")
    /// The Getting side of pickups.
    static let sky = Color("BrandSky")

    // MARK: - Surfaces and text, each with a dark variant

    /// Screen background. Paper in light mode, Night in dark mode.
    static let canvas = Color("BrandCanvas")
    /// Card background. White in light mode, a lifted green-black in dark mode.
    static let surface = Color("BrandSurface")
    /// Inset panels and stat tiles on a card. Paper in light mode, the card color in dark mode.
    static let tile = Color("BrandTile")
    /// Primary text.
    static let ink = Color("BrandInk")
    /// Secondary text.
    static let smoke = Color("BrandSmoke")
    /// Hairline borders on dark cards and on glass.
    static let hairline = Color("BrandHairline")
    /// The unfilled part of rings and stage connectors.
    static let track = Color("BrandTrack")
    /// Progress and "your move" accents. Leaf in light mode, Mint in dark mode, where Leaf is too dim on Night.
    static let progress = Color("BrandProgress")

    /// The ink color for shadows, in both modes. Cards use it at 8%, floating bars at 16%.
    static let shadow = Color(red: 15 / 255, green: 28 / 255, blue: 22 / 255)
    /// A mid green that ends the button gradient, so white text stays readable across the whole pill.
    static let leafLight = Color(red: 76 / 255, green: 185 / 255, blue: 126 / 255)

    /// The chip color for a listing's mode: Free on Leaf, Swap on Sun, Parts on Clay.
    static func color(for mode: ItemMode) -> Color {
        switch mode {
        case .give: leaf
        case .swap: sun
        case .parts: clay
        }
    }

    // MARK: - Gradients

    /// Renewal: Forest to Leaf to Mint at 135°. Hero cards, your chat bubbles, and the impact ring.
    static let renewal = LinearGradient(
        stops: [
            .init(color: forest, location: 0),
            .init(color: leaf, location: 0.6),
            .init(color: mint, location: 1),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// The gradient for pills and the floating Give button. It stops short of Mint, which never carries text.
    static let renewalButton = LinearGradient(
        stops: [
            .init(color: forest, location: 0),
            .init(color: leaf, location: 0.7),
            .init(color: leafLight, location: 1),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Shape

    enum Radius {
        /// Cards and photo tiles. Always with the continuous corner style.
        static let card: CGFloat = 20
        /// Stat tiles and inset panels.
        static let tile: CGFloat = 16
        /// Thumbnails inside a card.
        static let thumbnail: CGFloat = 16
        /// Chat bubbles.
        static let bubble: CGFloat = 20
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    enum Size {
        /// The one primary action on a screen.
        static let pillButton: CGFloat = 56
        /// Filter and glass chips.
        static let chip: CGFloat = 34
        /// Mode chips on photos.
        static let modeChip: CGFloat = 28
        /// The floating tab bar and the Give button.
        static let bar: CGFloat = 64
    }

    // MARK: - Type

    /// Every font is a Dynamic Type style, so nothing here is a fixed point size.
    enum Typography {
        /// Screen titles. Heavy weight, tightened by `displayTitle()`.
        static let display = Font.system(.largeTitle, design: .default, weight: .heavy)
        /// Counts and pounds. Rounded so numbers read as friendly.
        static func numerals(_ style: Font.TextStyle = .title) -> Font {
            .system(style, design: .rounded, weight: .bold)
        }
        /// Small uppercase labels above a group, like "Your move".
        static let label = Font.system(.caption2, weight: .heavy)
        static let chip = Font.system(.footnote, weight: .semibold)
        static let modeChip = Font.system(.caption, weight: .bold)
        static let button = Font.system(.body, weight: .bold)
        static let stageLabel = Font.system(.caption2, weight: .bold)
    }
}

extension View {
    /// A screen title: the heavy display face with tight tracking. Color is left to the caller.
    func displayTitle() -> some View {
        font(AnaneoTheme.Typography.display)
            .tracking(-0.8)
    }

    /// Rounded, tabular numerals for counts and pounds.
    func numerals(_ style: Font.TextStyle = .title) -> some View {
        font(AnaneoTheme.Typography.numerals(style))
            .monospacedDigit()
    }

    /// A small uppercase label above a group, like "Your move".
    func sectionLabel(_ color: Color = AnaneoTheme.smoke) -> some View {
        font(AnaneoTheme.Typography.label)
            .textCase(.uppercase)
            .kerning(1)
            .foregroundStyle(color)
    }
}

#Preview("Palette") {
    let swatches: [(String, Color)] = [
        ("Forest", AnaneoTheme.forest), ("Leaf", AnaneoTheme.leaf), ("Mint", AnaneoTheme.mint),
        ("Spark", AnaneoTheme.spark), ("Sun", AnaneoTheme.sun), ("Clay", AnaneoTheme.clay),
        ("Sky", AnaneoTheme.sky), ("Canvas", AnaneoTheme.canvas), ("Surface", AnaneoTheme.surface),
        ("Tile", AnaneoTheme.tile), ("Ink", AnaneoTheme.ink), ("Smoke", AnaneoTheme.smoke),
        ("Track", AnaneoTheme.track), ("Progress", AnaneoTheme.progress),
    ]
    ScrollView {
        VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.lg) {
            Text("Near you").displayTitle()
            Text("283.1 lbs").numerals(.largeTitle)
            Text("Renewal palette").sectionLabel()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96))], spacing: AnaneoTheme.Spacing.md) {
                ForEach(swatches, id: \.0) { name, color in
                    VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.xs) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(color)
                            .frame(height: 56)
                            .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(AnaneoTheme.hairline) }
                        Text(name).font(.footnote.weight(.semibold))
                    }
                }
            }
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AnaneoTheme.renewal)
                .frame(height: 20)
            Text("Renewal gradient, Forest to Leaf to Mint").font(.footnote).foregroundStyle(AnaneoTheme.smoke)
        }
        .padding()
    }
    .background(AnaneoTheme.canvas)
}
