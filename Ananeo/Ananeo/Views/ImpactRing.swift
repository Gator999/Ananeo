import SwiftUI

/// The hero on Impact: pounds kept from landfill inside the loop ring, which fills toward the next milestone.
struct ImpactRing: View {
    let pounds: Double

    static let milestones: [Double] = [25, 50, 100, 250, 500, 1000, 2500, 5000, 10000, 25000]

    /// The next round number of pounds to reach.
    var nextMilestone: Double {
        Self.milestones.first { $0 > pounds } ?? (Self.milestones.last ?? 25000)
    }

    /// 0 to 1 toward the next milestone, never quite empty so the ring reads as a ring.
    var progress: Double {
        max(0.02, min(1, pounds / nextMilestone))
    }

    var body: some View {
        LoopRing(progress: progress, lineWidth: 20, style: .gradient)
            .shadow(color: AnaneoTheme.mint.opacity(0.35), radius: 22)
            .overlay {
                VStack(spacing: AnaneoTheme.Spacing.xs) {
                    Text(pounds, format: .number.precision(.fractionLength(0...1)))
                        .numerals(.largeTitle)
                        .foregroundStyle(AnaneoTheme.ink)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("lbs kept from landfill")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(AnaneoTheme.progress)
                }
                .padding(.horizontal, 44)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(pounds.formatted(.number.precision(.fractionLength(0...1)))) pounds kept from landfill, \(Int(progress * 100)) percent of the way to \(Int(nextMilestone))")
    }
}

#Preview("Impact ring") {
    struct Demo: View {
        @State private var pounds = 283.1

        var body: some View {
            VStack(spacing: AnaneoTheme.Spacing.xxl) {
                ImpactRing(pounds: pounds).frame(width: 236)
                Button("Confirm a handoff") {
                    withAnimation(AnaneoMotion.roll()) { pounds += 14.3 }
                }
                .buttonStyle(.pill(.secondary, expanded: false))
            }
            .padding()
            .background(AnaneoTheme.canvas)
        }
    }
    return Demo()
}
