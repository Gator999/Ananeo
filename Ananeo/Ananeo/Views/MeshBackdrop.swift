import Combine
import SwiftUI

/// The Welcome background: a mesh of Forest, Leaf, and Mint that drifts slowly, with a Spark glow low on the left.
/// Runs at 30 frames per second, and holds still under Reduce Motion or Low Power Mode.
struct MeshBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var isPaused: Bool { reduceMotion || isLowPower }

    private static let colors: [Color] = [
        AnaneoTheme.forest, Color(red: 29 / 255, green: 170 / 255, blue: 110 / 255), AnaneoTheme.mint,
        AnaneoTheme.forest, AnaneoTheme.forest, AnaneoTheme.leaf,
        Color(red: 18 / 255, green: 105 / 255, blue: 74 / 255), AnaneoTheme.forest, AnaneoTheme.forest,
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: isPaused)) { context in
            let time = isPaused ? 0 : context.date.timeIntervalSinceReferenceDate
            MeshGradient(width: 3, height: 3, points: Self.points(at: time), colors: Self.colors)
        }
        .overlay {
            RadialGradient(
                colors: [AnaneoTheme.spark.opacity(0.18), .clear],
                center: UnitPoint(x: 0.2, y: 0.95),
                startRadius: 0,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange).receive(on: DispatchQueue.main)) { _ in
            isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .accessibilityHidden(true)
    }

    /// Corners stay put, edge points slide along their edge, and the center wanders, so the mesh never tears.
    private static func points(at time: TimeInterval) -> [SIMD2<Float>] {
        let t = Float(time)
        return [
            [0, 0], [0.5 + 0.12 * sin(t * 0.18), 0], [1, 0],
            [0, 0.45 + 0.1 * cos(t * 0.15)], [0.45 + 0.15 * sin(t * 0.12 + 1), 0.5 + 0.15 * cos(t * 0.1 + 2)], [1, 0.55 + 0.1 * sin(t * 0.14 + 3)],
            [0, 1], [0.5 + 0.12 * cos(t * 0.16 + 4), 1], [1, 1],
        ]
    }
}

#Preview("Mesh backdrop") {
    MeshBackdrop()
        .overlay {
            LoopMark.onGradient.frame(width: 172)
        }
}
