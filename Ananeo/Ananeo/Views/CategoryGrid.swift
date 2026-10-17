import SwiftUI

/// Every category as a tile, four across. The chosen one turns Ink.
struct CategoryGrid: View {
    @Binding var selection: ItemCategory

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = Array(repeating: GridItem(.flexible(), spacing: AnaneoTheme.Spacing.sm), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: AnaneoTheme.Spacing.sm) {
            ForEach(ItemCategory.allCases) { category in
                tile(category)
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
        .animation(AnaneoMotion.settle(reduceMotion: reduceMotion), value: selection)
    }

    private func tile(_ category: ItemCategory) -> some View {
        let isSelected = category == selection
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            selection = category
        } label: {
            VStack(spacing: AnaneoTheme.Spacing.xs + 2) {
                Image(systemName: category.systemImage)
                    .font(.title3)
                Text(category.title)
                    .font(.caption2.weight(isSelected ? .bold : .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AnaneoTheme.Spacing.sm + 2)
            .foregroundStyle(isSelected ? AnaneoTheme.canvas : AnaneoTheme.ink)
            .background(isSelected ? AnyShapeStyle(AnaneoTheme.ink) : AnyShapeStyle(AnaneoTheme.surface), in: shape)
            .overlay {
                if !isSelected {
                    shape.strokeBorder(AnaneoTheme.hairline, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Category grid") {
    struct Demo: View {
        @State private var category: ItemCategory = .furniture

        var body: some View {
            CategoryGrid(selection: $category)
                .padding()
                .background(AnaneoTheme.canvas)
        }
    }
    return Demo()
}
