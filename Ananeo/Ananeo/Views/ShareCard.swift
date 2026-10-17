import SwiftUI

/// A story-sized card of your totals on the gradient, rendered to an image for sharing.
/// Sizes are fixed points, not Dynamic Type, because this is a picture.
struct ShareCard: View {
    let impact: Impact

    static let size = CGSize(width: 360, height: 640)

    var body: some View {
        ZStack {
            AnaneoTheme.renewal
            RadialGradient(colors: [AnaneoTheme.spark.opacity(0.22), .clear], center: UnitPoint(x: 0.15, y: 0.9), startRadius: 0, endRadius: 260)
            VStack(spacing: 28) {
                Spacer()
                LoopMark.onGradient
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.3), radius: 18, y: 12)
                VStack(spacing: 6) {
                    Text(impact.poundsDiverted, format: .number.precision(.fractionLength(0...1)))
                        .font(.system(size: 88, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("lbs kept from landfill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AnaneoTheme.mint)
                }
                HStack(spacing: 10) {
                    stat(impact.itemsGiven, "given")
                    Text("·")
                    stat(impact.itemsReceived, "received")
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                Spacer()
                VStack(spacing: 4) {
                    Text("Ananeo")
                        .font(.system(size: 30, weight: .heavy))
                        .tracking(-0.8)
                    Text("Give More. Waste Less. Keep It Moving.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .padding(.bottom, 36)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .light)
    }

    private func stat(_ count: Int, _ label: String) -> Text {
        Text(count, format: .number).font(.system(size: 24, weight: .bold, design: .rounded)) + Text(" \(label)")
    }
}

extension ShareCard {
    /// Renders the card at 3x, which is 1080 by 1920 pixels, for the share sheet.
    @MainActor
    static func render(_ impact: Impact) -> Image? {
        let renderer = ImageRenderer(content: ShareCard(impact: impact))
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

#Preview("Share card") {
    ShareCard(impact: Impact(itemsGiven: 14, itemsReceived: 6, kgDiverted: 128.4))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding()
        .background(AnaneoTheme.canvas)
}
