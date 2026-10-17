import SwiftUI

#if DEBUG
/// Every Phase 0 component on one screen, for checking light, dark, Reduce Motion, and Dynamic Type at once.
/// Previews only. Nothing in the app shows it.
struct DesignGallery: View {
    @State private var stage = 2
    @State private var progress = 0.72

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.xxl) {
                VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.xs) {
                    Text("Ananeo design language").sectionLabel()
                    Text("Keep It Moving").displayTitle()
                }

                section("Buttons") {
                    HStack(spacing: AnaneoTheme.Spacing.md) {
                        Button("Ask for it", systemImage: "hand.raised") {}.buttonStyle(.pill)
                        Button("Message") {}.buttonStyle(.pill(.secondary, expanded: false))
                    }
                }

                section("Chips") {
                    HStack(spacing: AnaneoTheme.Spacing.sm) {
                        Chip(title: "Within 10 mi", systemImage: "location")
                        Chip(title: "All", isSelected: true)
                        ForEach(ItemMode.allCases) { ModeChip(mode: $0) }
                    }
                }

                section("Stage tracker") {
                    Card {
                        StageTracker(current: stage)
                    }
                    Stepper("Step \(stage)", value: $stage, in: 0...StageTracker.pickupSteps.count)
                }

                section("Loop ring") {
                    HStack(spacing: AnaneoTheme.Spacing.lg) {
                        LoopRing(progress: progress).frame(width: 56)
                        LoopRing(progress: progress, style: .gradient).frame(width: 56)
                        LoopRing(progress: nil).frame(width: 56)
                        LoopMark().frame(width: 56)
                        LoopMark.onGradient
                            .frame(width: 40)
                            .padding(AnaneoTheme.Spacing.sm)
                            .background(AnaneoTheme.renewal, in: Circle())
                    }
                    Slider(value: $progress, in: 0...1)
                }

                section("Stat tiles") {
                    HStack(spacing: AnaneoTheme.Spacing.md) {
                        StatTile(count: 14, label: "Items given")
                        StatTile(count: 6, label: "Items received")
                    }
                }

                section("Skeleton") {
                    HStack(spacing: AnaneoTheme.Spacing.md) {
                        Skeleton(cornerRadius: AnaneoTheme.Radius.card).frame(width: 96, height: 120)
                        VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.sm) {
                            Skeleton().frame(height: 14)
                            Skeleton().frame(width: 120, height: 12)
                        }
                    }
                }

                section("Glass bar") {
                    ZStack {
                        AnaneoTheme.renewal
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
                    .clipShape(RoundedRectangle(cornerRadius: AnaneoTheme.Radius.card, style: .continuous))
                }
            }
            .padding()
        }
        .background(AnaneoTheme.canvas)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.md) {
            Text(title).sectionLabel()
            content()
        }
    }
}

#Preview("Gallery, light") {
    DesignGallery()
}

#Preview("Gallery, dark") {
    DesignGallery()
        .preferredColorScheme(.dark)
}

#Preview("Gallery, XXL type") {
    DesignGallery()
        .dynamicTypeSize(.xxLarge)
}
#endif
