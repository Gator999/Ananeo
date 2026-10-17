import SwiftUI

/// A placeholder block that shimmers while content loads. Takes the place of spinners in feeds and cards.
struct Skeleton: View {
    var cornerRadius: CGFloat = AnaneoTheme.Radius.tile

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AnaneoTheme.track)
            .shimmer()
            .accessibilityHidden(true)
    }
}

/// Sweeps a soft highlight across the view every 1.4 seconds, clipped to the view's own shape.
/// Driven by a timeline, so it needs no state and restarts cleanly. Holds still under Reduce Motion.
private struct ShimmerModifier: ViewModifier {
    var isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if isActive && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    let cycle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
                    GeometryReader { geometry in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.3), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 0.6)
                        .offset(x: (cycle * 1.8 - 0.6) * geometry.size.width)
                    }
                }
                .mask { content }
                .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    /// Sweeps a highlight across the view, for placeholders.
    func shimmer() -> some View {
        modifier(ShimmerModifier(isActive: true))
    }

    /// Shows the view as a shimmering placeholder while loading. The layout stays, so nothing jumps when data lands.
    func skeleton(_ isLoading: Bool) -> some View {
        redacted(reason: isLoading ? .placeholder : [])
            .modifier(ShimmerModifier(isActive: isLoading))
    }
}

#Preview("Skeleton") {
    struct Demo: View {
        @State private var isLoading = true

        var body: some View {
            VStack(spacing: AnaneoTheme.Spacing.lg) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AnaneoTheme.Spacing.md) {
                    ForEach(0..<4) { _ in
                        VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.sm) {
                            Skeleton(cornerRadius: AnaneoTheme.Radius.card).aspectRatio(4 / 5, contentMode: .fit)
                            Skeleton().frame(width: 120, height: 14)
                            Skeleton().frame(width: 80, height: 12)
                        }
                    }
                }
                Card {
                    Text("Oak bookshelf").font(.headline)
                    Text("Solid wood, five shelves. Needs a pickup truck.")
                }
                .skeleton(isLoading)
                Toggle("Loading", isOn: $isLoading)
            }
            .padding()
            .background(AnaneoTheme.canvas)
        }
    }
    return Demo()
}
