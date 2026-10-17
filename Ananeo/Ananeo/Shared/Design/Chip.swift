import SwiftUI

/// A glass pill for filters, with an optional icon. Selected chips turn Ink with light text.
struct Chip: View {
    let title: String
    var systemImage: String? = nil
    var isSelected = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: AnaneoTheme.Spacing.sm - 2) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
            }
            Text(title)
        }
        .font(AnaneoTheme.Typography.chip)
        .foregroundStyle(isSelected ? AnaneoTheme.canvas : AnaneoTheme.ink)
        .padding(.horizontal, isSelected ? AnaneoTheme.Spacing.lg - 2 : AnaneoTheme.Spacing.md)
        .frame(height: AnaneoTheme.Size.chip)
        .background {
            if isSelected {
                Capsule().fill(AnaneoTheme.ink)
            } else {
                GlassBackground(shape: Capsule())
            }
        }
        .animation(AnaneoMotion.settle(reduceMotion: reduceMotion), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The colored mode label on a photo or a listing: Free on Leaf, Swap on Sun, Parts on Clay.
struct ModeChip: View {
    let mode: ItemMode

    var body: some View {
        Text(mode.title)
            .font(AnaneoTheme.Typography.modeChip)
            .foregroundStyle(mode == .swap ? AnaneoTheme.forest : .white)
            .padding(.horizontal, AnaneoTheme.Spacing.md - 2)
            .frame(height: AnaneoTheme.Size.modeChip)
            .background(AnaneoTheme.color(for: mode), in: Capsule())
    }
}

#Preview("Chips") {
    struct Demo: View {
        @State private var category: ItemCategory?

        var body: some View {
            VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.lg) {
                HStack(spacing: AnaneoTheme.Spacing.sm) {
                    Chip(title: "Within 10 mi", systemImage: "location")
                    Chip(title: "Any offer")
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AnaneoTheme.Spacing.sm) {
                        Button { category = nil } label: {
                            Chip(title: "All", isSelected: category == nil)
                        }
                        ForEach(ItemCategory.allCases) { item in
                            Button { category = item } label: {
                                Chip(title: item.title, systemImage: item.systemImage, isSelected: category == item)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                HStack(spacing: AnaneoTheme.Spacing.sm) {
                    ForEach(ItemMode.allCases) { ModeChip(mode: $0) }
                }
            }
            .padding()
            .background(AnaneoTheme.canvas)
        }
    }
    return Demo()
}
