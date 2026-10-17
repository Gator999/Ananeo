import SwiftUI

/// The ring from the app icon, filled from 0 to 1.
///
/// One shape for every spinner, stage gauge, and impact ring. Pass `progress: nil` for an indeterminate spinner.
/// Changes to `progress` fill with a spring, which stays still under Reduce Motion.
struct LoopRing: View {
    enum Style {
        /// Leaf in light mode, Mint in dark mode.
        case progress
        /// The Renewal gradient, for the impact ring.
        case gradient
        /// For rings on the gradient or on Forest.
        case white
    }

    /// 0 to 1. `nil` spins.
    var progress: Double?
    var lineWidth: CGFloat = 9
    var style: Style = .progress
    /// Whether the unfilled part of the ring is drawn.
    var showsTrack = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if showsTrack {
                Circle().stroke(trackStyle, lineWidth: lineWidth)
            }
            if let progress {
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(fill, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(AnaneoMotion.loopFill(reduceMotion: reduceMotion), value: progress)
            } else {
                Spinner(lineWidth: lineWidth, fill: fill, reduceMotion: reduceMotion)
            }
        }
        .padding(lineWidth / 2)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var fill: AnyShapeStyle {
        switch style {
        case .progress: AnyShapeStyle(AnaneoTheme.progress)
        case .gradient: AnyShapeStyle(AnaneoTheme.renewal)
        case .white: AnyShapeStyle(Color.white)
        }
    }

    private var trackStyle: AnyShapeStyle {
        style == .white ? AnyShapeStyle(Color.white.opacity(0.25)) : AnyShapeStyle(AnaneoTheme.track)
    }

    private var accessibilityText: String {
        if let progress { "\(Int((progress * 100).rounded())) percent" } else { "Loading" }
    }
}

/// Three tenths of the ring, going around once a second. Holds still under Reduce Motion.
private struct Spinner: View {
    let lineWidth: CGFloat
    let fill: AnyShapeStyle
    let reduceMotion: Bool

    @State private var isSpinning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.3)
            .stroke(fill, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(isSpinning ? 270 : -90))
            .animation(reduceMotion ? nil : .linear(duration: 1).repeatForever(autoreverses: false), value: isSpinning)
            .onAppear { isSpinning = true }
    }
}

/// One arrow of the loop mark: an arc of a circle with an arrowhead at its end, as a filled path.
///
/// `from` and `to` are fractions of the circle, clockwise from three o'clock. Animating `to` draws the arrow on.
struct LoopArrowShape: Shape {
    var from: Double
    var to: Double
    /// The stroke width as a fraction of the mark's side.
    var lineWidthRatio: CGFloat = 0.11

    var animatableData: Double {
        get { to }
        set { to = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let lineWidth = side * lineWidthRatio
        // Leave room for the arrowhead, which is wider than the stroke.
        let radius = side / 2 - lineWidth * 1.4
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let circle = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

        var path = Path(ellipseIn: circle)
            .trimmedPath(from: from, to: to)
            .strokedPath(StrokeStyle(lineWidth: lineWidth, lineCap: .round))

        let angle = to * 2 * .pi
        let end = CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
        let tangent = CGPoint(x: -CGFloat(sin(angle)), y: CGFloat(cos(angle)))
        let normal = CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle)))
        let tip = lineWidth * 0.9
        let back = lineWidth * 1.3
        let half = lineWidth * 1.3

        var head = Path()
        head.move(to: CGPoint(x: end.x + tangent.x * tip, y: end.y + tangent.y * tip))
        head.addLine(to: CGPoint(x: end.x - tangent.x * back + normal.x * half, y: end.y - tangent.y * back + normal.y * half))
        head.addLine(to: CGPoint(x: end.x - tangent.x * back - normal.x * half, y: end.y - tangent.y * back - normal.y * half))
        head.closeSubpath()
        path.addPath(head)
        return path
    }
}

/// The two-arrow loop from the app icon. The community mark, and the full loop when a handoff completes.
///
/// `drawn` goes from 0 to 1 to draw both arrows on, as on the Welcome screen.
struct LoopMark: View {
    var primary: Color = AnaneoTheme.leaf
    var secondary: Color = AnaneoTheme.forest
    var drawn: Double = 1

    private static let top = (from: 200.0 / 360, to: 340.0 / 360)
    private static let bottom = (from: 20.0 / 360, to: 160.0 / 360)

    var body: some View {
        ZStack {
            LoopArrowShape(from: Self.top.from, to: Self.top.from + (Self.top.to - Self.top.from) * drawn)
                .fill(primary)
            LoopArrowShape(from: Self.bottom.from, to: Self.bottom.from + (Self.bottom.to - Self.bottom.from) * drawn)
                .fill(secondary)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

extension LoopMark {
    /// White and Spark, for the gradient and Forest.
    static var onGradient: LoopMark {
        LoopMark(primary: .white, secondary: AnaneoTheme.spark)
    }
}

#Preview("Loop ring and mark") {
    struct Demo: View {
        @State private var progress = 0.25
        @State private var drawn = 1.0

        var body: some View {
            VStack(spacing: AnaneoTheme.Spacing.xxl) {
                HStack(spacing: AnaneoTheme.Spacing.lg) {
                    LoopRing(progress: progress).frame(width: 64)
                    LoopRing(progress: progress, style: .gradient).frame(width: 64)
                    LoopRing(progress: nil).frame(width: 64)
                    LoopMark().frame(width: 64)
                }
                Slider(value: $progress, in: 0...1)
                HStack(spacing: AnaneoTheme.Spacing.lg) {
                    LoopRing(progress: 0.72, lineWidth: 20, style: .gradient)
                        .frame(width: 180)
                        .overlay {
                            VStack(spacing: AnaneoTheme.Spacing.xs) {
                                Text("128.4").numerals(.largeTitle)
                                Text("kg kept from landfill").font(.footnote.weight(.semibold)).foregroundStyle(AnaneoTheme.smoke)
                            }
                        }
                    VStack {
                        LoopMark.onGradient
                            .frame(width: 96)
                            .padding()
                            .background(AnaneoTheme.renewal, in: RoundedRectangle(cornerRadius: AnaneoTheme.Radius.card, style: .continuous))
                        LoopMark(drawn: drawn).frame(width: 64)
                    }
                }
                Slider(value: $drawn, in: 0...1)
                Text("Drag the second slider to draw the loop on.").font(.footnote).foregroundStyle(AnaneoTheme.smoke)
            }
            .padding()
            .background(AnaneoTheme.canvas)
        }
    }
    return Demo()
}
