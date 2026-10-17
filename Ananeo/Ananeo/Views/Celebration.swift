import SwiftUI

/// Particles for a confirmed handoff: up to 80 flecks of Spark, Mint, Leaf, and white burst up and fall away.
/// Plays once for about two seconds, and draws nothing under Reduce Motion.
struct Celebration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var particles = (0..<80).map { _ in Particle.random() }

    private static let duration: TimeInterval = 1.8

    private struct Particle {
        let angle: Double
        let speed: Double
        let size: Double
        let delay: Double
        let color: Color

        static func random() -> Particle {
            Particle(
                angle: .random(in: 0.35...2.8),
                speed: .random(in: 260...620),
                size: .random(in: 5...11),
                delay: .random(in: 0...0.25),
                color: [AnaneoTheme.spark, AnaneoTheme.mint, AnaneoTheme.leaf, .white].randomElement() ?? AnaneoTheme.spark
            )
        }
    }

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation(minimumInterval: 1 / 60)) { context in
                let elapsed = context.date.timeIntervalSince(start)
                Canvas { graphics, size in
                    guard elapsed < Self.duration else { return }
                    let origin = CGPoint(x: size.width / 2, y: size.height * 0.45)
                    for particle in particles {
                        let life = elapsed - particle.delay
                        guard life > 0 else { continue }
                        let x = origin.x + CGFloat(cos(particle.angle) * particle.speed * life)
                        let y = origin.y - CGFloat(sin(particle.angle) * particle.speed * life) + CGFloat(420 * life * life)
                        let rect = CGRect(x: x, y: y, width: particle.size, height: particle.size * 0.6)
                        graphics.opacity = max(0, 1 - life / 1.4)
                        graphics.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(particle.color))
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

#Preview("Celebration") {
    struct Demo: View {
        @State private var playing = false

        var body: some View {
            ZStack {
                AnaneoTheme.canvas.ignoresSafeArea()
                Button("Confirm handoff") {
                    playing = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(50))
                        playing = true
                    }
                }
                .buttonStyle(.pill(.primary, expanded: false))
                if playing {
                    Celebration()
                }
            }
        }
    }
    return Demo()
}
