import SwiftUI

/// A number with a label, in rounded numerals on an inset tile. The number rolls when it changes inside `withAnimation`.
struct StatTile: View {
    let value: String
    let label: String
    var tint: Color = AnaneoTheme.ink

    @Environment(\.colorScheme) private var colorScheme

    init(value: String, label: String, tint: Color = AnaneoTheme.ink) {
        self.value = value
        self.label = label
        self.tint = tint
    }

    init(count: Int, label: String, tint: Color = AnaneoTheme.ink) {
        self.init(value: count.formatted(), label: label, tint: tint)
    }

    init(pounds: Double, label: String, tint: Color = AnaneoTheme.ink) {
        self.init(value: pounds.formatted(.number.precision(.fractionLength(0...1))) + " lbs", label: label, tint: tint)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AnaneoTheme.Radius.tile, style: .continuous)
        VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.xs) {
            Text(value)
                .numerals(.title)
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AnaneoTheme.smoke)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AnaneoTheme.Spacing.lg)
        .background(AnaneoTheme.tile, in: shape)
        .overlay {
            if colorScheme == .dark {
                shape.strokeBorder(AnaneoTheme.hairline, lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Stat tiles") {
    struct Demo: View {
        @State private var given = 14
        @State private var pounds = 283.1

        var body: some View {
            VStack(spacing: AnaneoTheme.Spacing.lg) {
                HStack(spacing: AnaneoTheme.Spacing.md) {
                    StatTile(count: given, label: "Items given")
                    StatTile(count: 6, label: "Items received")
                }
                StatTile(pounds: pounds, label: "Kept from landfill", tint: AnaneoTheme.progress)
                Button("Confirm a handoff") {
                    withAnimation(AnaneoMotion.roll()) {
                        given += 1
                        pounds += 14.3
                    }
                }
                .buttonStyle(.pill(.secondary))
            }
            .padding()
            .background(AnaneoTheme.canvas)
        }
    }
    return Demo()
}
