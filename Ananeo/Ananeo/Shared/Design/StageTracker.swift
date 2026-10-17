import SwiftUI

/// The steps from request to handoff. Done steps fill with a check, the current one pulses, and each connector
/// fills with a spring when the other person acts.
struct StageTracker: View {
    static let pickupSteps = ["Asked", "Reserved", "Confirm", "Done"]

    var steps: [String] = StageTracker.pickupSteps
    /// The step in progress. Steps before it are done. Pass `steps.count` when every step is done.
    var current: Int
    var accent: Color = AnaneoTheme.progress

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric private var dotSize: CGFloat = 22

    private enum StepState {
        case done, current, upcoming
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, title in
                step(title, state: state(of: index))
                if index < steps.count - 1 {
                    connector(fill: fill(after: index))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func state(of index: Int) -> StepState {
        if index < current { .done } else if index == current { .current } else { .upcoming }
    }

    /// Full between two done steps, half from a done step to the current one, empty after that.
    private func fill(after index: Int) -> Double {
        if index + 1 < current { 1 } else if index + 1 == current { 0.5 } else { 0 }
    }

    private var accessibilityText: String {
        if current >= steps.count { return "All \(steps.count) steps done" }
        return "Step \(current + 1) of \(steps.count): \(steps[current])"
    }

    private func step(_ title: String, state: StepState) -> some View {
        VStack(spacing: AnaneoTheme.Spacing.xs + 1) {
            dot(state)
            Text(title)
                .font(AnaneoTheme.Typography.stageLabel)
                .foregroundStyle(labelColor(state))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(minWidth: dotSize * 2.6)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func labelColor(_ state: StepState) -> Color {
        switch state {
        case .done: AnaneoTheme.ink
        case .current: accent
        case .upcoming: AnaneoTheme.smoke
        }
    }

    private func dot(_ state: StepState) -> some View {
        ZStack {
            if state == .current {
                halo
            }
            switch state {
            case .done:
                Circle().fill(accent)
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.heavy))
                    .imageScale(.small)
                    .foregroundStyle(AnaneoTheme.canvas)
            case .current:
                Circle().fill(AnaneoTheme.surface)
                Circle().strokeBorder(accent, lineWidth: 3)
            case .upcoming:
                Circle().fill(AnaneoTheme.surface)
                Circle().strokeBorder(AnaneoTheme.track, lineWidth: 2)
            }
        }
        .frame(width: dotSize, height: dotSize)
    }

    /// A soft ring behind the current step that swells and fades. Holds still under Reduce Motion.
    @ViewBuilder
    private var halo: some View {
        let ring = Circle()
            .fill(accent.opacity(0.18))
            .frame(width: dotSize + 10, height: dotSize + 10)
        if reduceMotion {
            ring
        } else {
            ring.phaseAnimator([false, true]) { view, swelling in
                view
                    .scaleEffect(swelling ? 1.35 : 1)
                    .opacity(swelling ? 0 : 1)
            } animation: { _ in
                .easeInOut(duration: 1.1)
            }
        }
    }

    private func connector(fill: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(AnaneoTheme.track)
                Capsule().fill(accent).frame(width: geometry.size.width * fill)
            }
        }
        .frame(height: 3)
        .padding(.top, dotSize / 2 - 1.5)
        .animation(AnaneoMotion.loopFill(reduceMotion: reduceMotion), value: fill)
    }
}

#Preview("Stage tracker") {
    struct Demo: View {
        @State private var current = 2

        var body: some View {
            VStack(spacing: AnaneoTheme.Spacing.xl) {
                Card {
                    Text("Oak bookshelf").font(.headline)
                    StageTracker(current: current)
                }
                Card {
                    Text("Getting, in Sky").font(.headline)
                    StageTracker(current: current, accent: AnaneoTheme.sky)
                }
                Stepper("Step \(current)", value: $current, in: 0...StageTracker.pickupSteps.count)
            }
            .padding()
            .background(AnaneoTheme.canvas)
        }
    }
    return Demo()
}
