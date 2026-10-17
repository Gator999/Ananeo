import SwiftUI

extension Pickup {
    /// Where the item is on the Asked, Reserved, Confirm, Done tracker. `nil` once it fell through.
    var trackerStep: Int? {
        switch stage {
        case .open: 0
        case .reserved: 2
        case .done: StageTracker.pickupSteps.count
        case .unavailable: nil
        }
    }

    /// The person on the other side: whoever it is reserved for, else the first person who asked.
    var counterpart: PickupRequest? {
        reservation ?? requests.first
    }

    /// One line on where things stand, from the signed-in user's side.
    var statusLine: String {
        let name = counterpart?.otherName ?? "Someone"
        switch stage {
        case .open:
            if !isGiver { return "Asked \(name). Waiting to hear back." }
            return requests.count == 1 ? "\(name) asked for it" : "\(requests.count) people asked for it"
        case .reserved:
            guard let handoff = reservation?.handoff else { return "Reserved" }
            if handoff.confirmedByMe { return "You confirmed. Waiting for \(name)." }
            if handoff.confirmedByThem { return "\(name) confirmed. Confirm yours." }
            return isGiver ? "Reserved for \(name)" : "Reserved for you"
        case .done:
            return isGiver ? "Given to \(name)" : "Received from \(name)"
        case .unavailable:
            return "No longer available"
        }
    }

    /// The short chip on a card that needs you: choose someone, or confirm.
    var moveLabel: String {
        stage == .open && isGiver ? "Choose" : "Your move"
    }
}

/// Someone's initial on a gradient: Forest to Leaf for the giving side, Sky for the getting side.
struct PersonBadge: View {
    let name: String
    var isGetting = false
    var size: CGFloat = 28

    var body: some View {
        Text(initial)
            .font(size >= 40 ? AnaneoTheme.Typography.numerals(.title3) : AnaneoTheme.Typography.numerals(.caption))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(gradient, in: Circle())
            .overlay { Circle().strokeBorder(AnaneoTheme.surface, lineWidth: 2) }
            .accessibilityHidden(true)
    }

    private var initial: String {
        name.first.map { String($0).uppercased() } ?? "?"
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: isGetting
                ? [Color(red: 43 / 255, green: 124 / 255, blue: 181 / 255), AnaneoTheme.sky]
                : [AnaneoTheme.forest, AnaneoTheme.leaf],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// One pickup in the list: the item, who it is with, where it stands, and the stage tracker while it is live.
/// Items waiting on you glow Leaf and carry a "Your move" chip.
struct PickupCard: View {
    @Environment(ListingService.self) private var listings
    @Environment(ChatService.self) private var chat
    let pickup: Pickup

    private var accent: Color { pickup.isGiver ? AnaneoTheme.progress : AnaneoTheme.sky }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AnaneoTheme.Radius.card, style: .continuous)
        VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.lg - 2) {
            HStack(spacing: AnaneoTheme.Spacing.md) {
                thumbnail
                VStack(alignment: .leading, spacing: 3) {
                    Text(pickup.title)
                        .font(.headline)
                        .foregroundStyle(AnaneoTheme.ink)
                        .lineLimit(1)
                    Text(pickup.statusLine)
                        .font(.footnote.weight(pickup.needsYou ? .semibold : .regular))
                        .foregroundStyle(pickup.needsYou ? accent : AnaneoTheme.smoke)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                trailing
            }
            if let step = pickup.trackerStep, pickup.stage != .done {
                StageTracker(current: step, accent: accent)
            }
        }
        .card(padding: AnaneoTheme.Spacing.md + 2)
        .overlay {
            if pickup.needsYou {
                shape.strokeBorder(accent, lineWidth: 2)
            }
        }
        .shadow(color: pickup.needsYou ? accent.opacity(0.22) : .clear, radius: 15, y: 12)
        .accessibilityElement(children: .combine)
    }

    private var thumbnail: some View {
        ListingPhoto(urls: pickup.photo.map(listings.gridURLs) ?? [], placeholder: pickup.category.systemImage)
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: AnaneoTheme.Radius.thumbnail, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                thumbnailBadge.offset(x: 6, y: 6)
            }
            .padding(.trailing, 4)
    }

    /// The other person's initial, or how many people asked while the giver is still choosing.
    @ViewBuilder
    private var thumbnailBadge: some View {
        if pickup.isGiver, pickup.stage == .open, pickup.requests.count > 1 {
            Text(pickup.requests.count, format: .number)
                .numerals(.caption2)
                .foregroundStyle(AnaneoTheme.canvas)
                .frame(minWidth: 28)
                .frame(height: 28)
                .background(AnaneoTheme.ink, in: Capsule())
                .overlay { Capsule().strokeBorder(AnaneoTheme.surface, lineWidth: 2) }
        } else if let person = pickup.counterpart {
            PersonBadge(name: person.otherName, isGetting: !pickup.isGiver)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        let unread = chat.unreadCount(in: pickup)
        VStack(alignment: .trailing, spacing: AnaneoTheme.Spacing.sm) {
            if pickup.needsYou {
                Text(pickup.moveLabel)
                    .font(AnaneoTheme.Typography.modeChip)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AnaneoTheme.Spacing.sm + 2)
                    .frame(minHeight: 26)
                    .background(accent, in: Capsule())
            } else if pickup.stage == .reserved {
                LoopRing(progress: 0.75, lineWidth: 5)
                    .frame(width: 34)
            }
            if unread > 0 {
                Label("\(unread)", systemImage: "bubble.left.fill")
                    .font(AnaneoTheme.Typography.modeChip)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AnaneoTheme.Spacing.sm)
                    .frame(minHeight: 24)
                    .background(AnaneoTheme.clay, in: Capsule())
                    .accessibilityLabel("\(unread) unread messages")
            }
        }
    }
}

#Preview("Pickup cards") {
    ScrollView {
        VStack(spacing: AnaneoTheme.Spacing.md) {
            PickupCard(pickup: .preview)
            PickupCard(pickup: Pickup(
                id: UUID(), title: "Desk lamp", category: .household, photo: nil, status: .available, isGiver: true,
                requests: [
                    PickupRequest(id: UUID(), otherUserID: UUID(), otherName: "Bob", requestedAt: .now.addingTimeInterval(-3600), handoff: nil),
                    PickupRequest(id: UUID(), otherUserID: UUID(), otherName: "Carol", requestedAt: .now, handoff: nil),
                ]
            ))
            PickupCard(pickup: Pickup(
                id: UUID(), title: "Monstera", category: .other, photo: nil, status: .reserved, isGiver: false,
                requests: [
                    PickupRequest(id: UUID(), otherUserID: UUID(), otherName: "Priya", requestedAt: .now,
                                  handoff: Handoff(id: UUID(), confirmedByMe: true, confirmedByThem: false, completedAt: nil)),
                ]
            ))
        }
        .padding()
    }
    .background(AnaneoTheme.canvas)
    .environment(ListingService())
    .environment(ChatService.preview())
}
