import SwiftUI

/// Give away, Swap, or Parts as three cards. The chosen one fills with the gradient and a Spark check.
struct ModeCards: View {
    @Binding var selection: ItemMode

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: AnaneoTheme.Spacing.sm + 2) {
            ForEach(ItemMode.allCases) { mode in
                card(mode)
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
        .animation(AnaneoMotion.settle(reduceMotion: reduceMotion), value: selection)
    }

    private func card(_ mode: ItemMode) -> some View {
        let isSelected = mode == selection
        let tint = AnaneoTheme.color(for: mode)
        let shape = RoundedRectangle(cornerRadius: AnaneoTheme.Radius.card - 2, style: .continuous)
        return Button {
            selection = mode
        } label: {
            VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.xs) {
                Text(mode.pickerTitle)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(isSelected ? .white : AnaneoTheme.ink)
                Text(Self.subtitle(mode))
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : AnaneoTheme.smoke)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
            .padding(AnaneoTheme.Spacing.md + 2)
            .background {
                if isSelected {
                    shape.fill(AnaneoTheme.renewalButton)
                        .shadow(color: AnaneoTheme.leaf.opacity(0.3), radius: 12, y: 10)
                } else {
                    shape.fill(tint.opacity(mode == .give ? 0.1 : 0.16))
                        .overlay { shape.strokeBorder(tint.opacity(0.5), lineWidth: 1) }
                }
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(AnaneoTheme.forest)
                        .frame(width: 20, height: 20)
                        .background(AnaneoTheme.spark, in: Circle())
                        .padding(AnaneoTheme.Spacing.sm + 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private static func subtitle(_ mode: ItemMode) -> String {
        switch mode {
        case .give: "Free to whoever you choose"
        case .swap: "Say what you'd like"
        case .parts: "For fixers and makers"
        }
    }
}

#Preview("Mode cards") {
    struct Demo: View {
        @State private var mode: ItemMode = .give

        var body: some View {
            ModeCards(selection: $mode)
                .padding()
                .background(AnaneoTheme.canvas)
        }
    }
    return Demo()
}
