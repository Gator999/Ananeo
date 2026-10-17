import SwiftUI

/// The hero on Impact: kilograms kept from landfill inside the loop ring, which fills toward the next milestone.
struct ImpactRing: View {
    let kilograms: Double

    static let milestones: [Double] = [10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000]

    /// The next round number of kilograms to reach.
    var nextMilestone: Double {
        Self.milestones.first { $0 > kilograms } ?? (Self.milestones.last ?? 10000)
    }

    /// 0 to 1 toward the next milestone, never quite empty so the ring reads as a ring.
    var progress: Double {
        max(0.02, min(1, kilograms / nextMilestone))
    }

    var body: some View {
        LoopRing(progress: progress, lineWidth: 20, style: .gradient)
            .shadow(color: AnaneoTheme.mint.opacity(0.35), radius: 22)
            .overlay {
                VStack(spacing: AnaneoTheme.Spacing.xs) {
                    Text(kilograms, format: .number.precision(.fractionLength(0...1)))
                        .numerals(.largeTitle)
                        .foregroundStyle(AnaneoTheme.ink)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("kg kept from landfill")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(AnaneoTheme.progress)
                }
                .padding(.horizontal, 44)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(kilograms.formatted(.number.precision(.fractionLength(0...1)))) kilograms kept from landfill, \(Int(progress * 100)) percent of the way to \(Int(nextMilestone))")
    }
}

#Preview("Impact ring") {
    struct Demo: View {
        @State private var kilograms = 128.4

        var body: some View {
            VStack(spacing: AnaneoTheme.Spacing.xxl) {
                ImpactRing(kilograms: kilograms).frame(width: 236)
                Button("Confirm a handoff") {
                    withAnimation(AnaneoMotion.roll()) { kilograms += 6.5 }
                }
                .buttonStyle(.pill(.secondary, expanded: false))
            }
            .padding()
            .background(AnaneoTheme.canvas)
        }
    }
    return Demo()
}
