import SwiftUI

/// The Pickups tab: everything you're giving or getting, from the first request to a confirmed handoff.
/// Items waiting on you come first.
struct PickupsView: View {
    @Environment(PickupService.self) private var pickups
    @Environment(ChatService.self) private var chat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Segment: String, CaseIterable, Identifiable {
        case giving = "Giving"
        case getting = "Getting"
        case done = "Done"

        var id: String { rawValue }
    }

    @State private var segment: Segment = .giving
    @State private var errorMessage: String?

    private var shown: [Pickup] {
        switch segment {
        case .giving: pickups.all.filter { $0.isGiver && $0.stage != .done }
        case .getting: pickups.all.filter { !$0.isGiver && $0.stage != .done }
        case .done: pickups.all.filter { $0.stage == .done }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AnaneoTheme.Spacing.lg) {
                    header
                    SegmentedPill(selection: $segment)
                    content
                }
                .padding(.horizontal, AnaneoTheme.Spacing.xl)
                .padding(.bottom, AnaneoTheme.Spacing.xxl)
            }
            .background(AnaneoTheme.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { itemID in
                PickupDetailView(itemID: itemID)
            }
            .refreshable {
                await load()
                try? await chat.refresh()
            }
            .task { await load() }
            .animation(AnaneoMotion.settle(reduceMotion: reduceMotion), value: segment)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.xs + 2) {
            if pickups.needsYouCount > 0 {
                Text(pickups.needsYouCount == 1 ? "1 waiting on you" : "\(pickups.needsYouCount) waiting on you")
                    .sectionLabel(AnaneoTheme.progress)
            } else {
                Text("Giving and getting").sectionLabel()
            }
            Text("Pickups")
                .displayTitle()
                .foregroundStyle(AnaneoTheme.ink)
        }
        .padding(.top, AnaneoTheme.Spacing.sm)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage, pickups.all.isEmpty {
            ContentUnavailableView {
                Label("Couldn't Load Pickups", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") { Task { await load() } }
                    .buttonStyle(.pill(.secondary, expanded: false))
            }
            .padding(.top, AnaneoTheme.Spacing.xxl)
        } else if !pickups.hasLoaded {
            ForEach(0..<3, id: \.self) { _ in
                Skeleton(cornerRadius: AnaneoTheme.Radius.card).frame(height: 150)
            }
        } else if shown.isEmpty {
            emptyState
                .padding(.top, AnaneoTheme.Spacing.xxl)
        } else {
            let yourMove = shown.filter(\.needsYou)
            let waiting = shown.filter { !$0.needsYou }
            if !yourMove.isEmpty {
                Text("Your move").sectionLabel(AnaneoTheme.progress)
                ForEach(yourMove) { card($0) }
            }
            if !waiting.isEmpty {
                Text(segment == .done ? "Kept moving" : "Waiting on them")
                    .sectionLabel()
                    .padding(.top, yourMove.isEmpty ? 0 : AnaneoTheme.Spacing.sm)
                ForEach(waiting) { card($0) }
            }
        }
    }

    private func card(_ pickup: Pickup) -> some View {
        NavigationLink(value: pickup.id) {
            PickupCard(pickup: pickup)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var emptyState: some View {
        switch segment {
        case .giving:
            ContentUnavailableView(
                "Nothing You're Giving Yet",
                systemImage: "hand.raised",
                description: Text("Post something with the Give button. Requests show up here.")
            )
        case .getting:
            ContentUnavailableView(
                "Nothing You're Getting Yet",
                systemImage: "arrow.left.arrow.right",
                description: Text("Ask for something in Browse and follow it here.")
            )
        case .done:
            ContentUnavailableView(
                "No Handoffs Yet",
                systemImage: "checkmark.circle",
                description: Text("Completed handoffs land here and count toward your impact.")
            )
        }
    }

    private func load() async {
        do {
            try await pickups.refresh()
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Giving, Getting, Done in one glass pill. The thumb slides to the chosen one.
private struct SegmentedPill: View {
    @Binding var selection: PickupsView.Segment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var thumb

    var body: some View {
        HStack(spacing: AnaneoTheme.Spacing.xs) {
            ForEach(PickupsView.Segment.allCases) { segment in
                let isSelected = segment == selection
                Button {
                    selection = segment
                } label: {
                    Text(segment.rawValue)
                        .font(.subheadline.weight(isSelected ? .bold : .semibold))
                        .foregroundStyle(isSelected ? AnaneoTheme.canvas : AnaneoTheme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 38)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(AnaneoTheme.ink)
                                    .matchedGeometryEffect(id: "thumb", in: thumb)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(AnaneoTheme.Spacing.xs)
        .glass()
        .sensoryFeedback(.selection, trigger: selection)
        .animation(AnaneoMotion.settle(reduceMotion: reduceMotion), value: selection)
    }
}

#Preview {
    PickupsView()
        .environment(PickupService.preview([.preview]))
        .environment(ListingService())
        .environment(ChatService.preview())
}
