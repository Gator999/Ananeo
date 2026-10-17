import SwiftUI

/// The five conditions in one segmented pill. Repair and parts read in Clay, since they route to fixers.
struct ConditionRow: View {
    @Binding var selection: ItemCondition

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var thumb

    var body: some View {
        HStack(spacing: AnaneoTheme.Spacing.xs) {
            ForEach(ItemCondition.allCases) { condition in
                segment(condition)
            }
        }
        .padding(AnaneoTheme.Spacing.xs)
        .background(AnaneoTheme.track, in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
        .animation(AnaneoMotion.settle(reduceMotion: reduceMotion), value: selection)
    }

    private func segment(_ condition: ItemCondition) -> some View {
        let isSelected = condition == selection
        let needsWork = condition == .needsRepair || condition == .forParts
        return Button {
            selection = condition
        } label: {
            Text(Self.shortTitle(condition))
                .font(.caption.weight(isSelected ? .bold : .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isSelected ? AnaneoTheme.ink : (needsWork ? AnaneoTheme.clay : AnaneoTheme.smoke))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(AnaneoTheme.surface)
                            .shadow(color: AnaneoTheme.shadow.opacity(0.12), radius: 4, y: 2)
                            .matchedGeometryEffect(id: "thumb", in: thumb)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(condition.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private static func shortTitle(_ condition: ItemCondition) -> String {
        switch condition {
        case .needsRepair: "Repair"
        case .forParts: "Parts"
        default: condition.title
        }
    }
}

#Preview("Condition row") {
    struct Demo: View {
        @State private var condition: ItemCondition = .good

        var body: some View {
            ConditionRow(selection: $condition)
                .padding()
                .background(AnaneoTheme.canvas)
        }
    }
    return Demo()
}
