import SwiftUI

/// A glass surface behind chips and bars. Liquid Glass on iOS 26, a system material with a hairline below it.
///
/// The iOS 26 branch only compiles with the Xcode 26 toolchain, so Xcode 16 builds always take the material path.
struct GlassBackground<S: Shape>: View {
    var shape: S

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if reduceTransparency {
            solid
        } else {
            glass
        }
    }

    @ViewBuilder
    private var glass: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(.regular, in: shape)
        } else {
            material
        }
        #else
        material
        #endif
    }

    private var material: some View {
        shape
            .fill(.regularMaterial)
            .overlay { shape.stroke(AnaneoTheme.hairline, lineWidth: 1) }
    }

    /// Reduce Transparency: the card color with a hairline, no blur.
    private var solid: some View {
        shape
            .fill(AnaneoTheme.surface)
            .overlay { shape.stroke(AnaneoTheme.hairline, lineWidth: 1) }
    }
}

/// A floating glass bar for the tab bar and composers.
struct GlassBar<Content: View>: View {
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, AnaneoTheme.Spacing.sm)
        .frame(height: AnaneoTheme.Size.bar)
        .background { GlassBackground(shape: Capsule()) }
        .shadow(color: colorScheme == .dark ? .black.opacity(0.4) : AnaneoTheme.shadow.opacity(0.16), radius: 16, y: 12)
    }
}

extension View {
    /// Puts the view on a glass capsule.
    func glass() -> some View {
        background { GlassBackground(shape: Capsule()) }
    }

    /// Puts the view on glass cut to the given shape.
    func glass<S: Shape>(in shape: S) -> some View {
        background { GlassBackground(shape: shape) }
    }
}

#Preview("Glass bar") {
    ZStack(alignment: .bottom) {
        AnaneoTheme.renewal.ignoresSafeArea()
        GlassBar {
            ForEach(["Browse", "Pickups", "Places", "Impact"], id: \.self) { title in
                VStack(spacing: 3) {
                    Image(systemName: "circle")
                    Text(title).font(.caption2.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
    }
}
