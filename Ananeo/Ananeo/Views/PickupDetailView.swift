import SwiftUI

/// One pickup from either side: choose who gets it, confirm the handoff, or step back.
struct PickupDetailView: View {
    @Environment(PickupService.self) private var pickups
    @Environment(ListingService.self) private var listings
    @Environment(ChatService.self) private var chat
    @Environment(\.dismiss) private var dismiss

    let itemID: UUID

    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var choosing: PickupRequest?
    @State private var confirmingHandoff = false
    @State private var confirmingCancel = false
    @State private var confirmingWithdraw = false
    @State private var isCelebrating = false

    var body: some View {
        Group {
            if let pickup = pickups.pickup(for: itemID) {
                content(pickup)
            } else {
                ContentUnavailableView("No Longer in Pickups", systemImage: "tray")
            }
        }
        .background(AnaneoTheme.canvas)
        .hidesFloatingTabBar()
    }

    private func content(_ pickup: Pickup) -> some View {
        let name = pickup.counterpart?.otherName ?? "them"
        let accent = pickup.isGiver ? AnaneoTheme.progress : AnaneoTheme.sky

        return ScrollView {
            VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.xl) {
                itemCard(pickup, accent: accent)

                if pickup.isGiver {
                    givingSections(pickup)
                } else {
                    gettingSections(pickup)
                }

                messagesSection(pickup)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, AnaneoTheme.Spacing.xl)
            .padding(.vertical, AnaneoTheme.Spacing.lg)
        }
        .overlay {
            if isCelebrating {
                Celebration()
            }
        }
        .navigationTitle(pickup.title)
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isWorking)
        .refreshable { try? await pickups.refresh() }
        .sensoryFeedback(trigger: isCelebrating) { _, playing in playing ? .success : nil }
        .onChange(of: pickup.stage == .done) { wasDone, isDone in
            if isDone && !wasDone { celebrate() }
        }
        .confirmationDialog(
            "Reserve for \(choosing?.otherName ?? "them")?",
            isPresented: Binding(get: { choosing != nil }, set: { if !$0 { choosing = nil } }),
            titleVisibility: .visible,
            presenting: choosing
        ) { request in
            Button("Reserve") {
                Task { await perform { try await pickups.reserve(pickup, for: request) } }
            }
        } message: { _ in
            Text("It comes off Browse while it's reserved. You can cancel if plans fall through.")
        }
        .confirmationDialog(
            pickup.isGiver ? "Did \(name) pick it up?" : "Did you get it?",
            isPresented: $confirmingHandoff,
            titleVisibility: .visible
        ) {
            Button(pickup.isGiver ? "Yes, Handed Off" : "Yes, I Got It") {
                guard let handoff = pickup.reservation?.handoff else { return }
                Task { await perform { try await pickups.confirm(handoff) } }
            }
        } message: {
            Text("Once you both confirm, it counts toward your impact. This can't be undone.")
        }
        .confirmationDialog("Cancel the reservation?", isPresented: $confirmingCancel, titleVisibility: .visible) {
            Button("Cancel Reservation", role: .destructive) {
                Task { await perform { try await pickups.cancelReservation(pickup) } }
            }
        } message: {
            Text("It goes back on Browse, and you can choose someone else.")
        }
        .confirmationDialog(
            pickup.stage == .reserved ? "Back out of this pickup?" : "Withdraw your request?",
            isPresented: $confirmingWithdraw,
            titleVisibility: .visible
        ) {
            Button(pickup.stage == .reserved ? "Back Out" : "Withdraw Request", role: .destructive) {
                Task { await withdraw(pickup) }
            }
        } message: {
            Text("\(name) can give it to someone else.")
        }
    }

    // MARK: - Item

    private func itemCard(_ pickup: Pickup, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.lg) {
            HStack(spacing: AnaneoTheme.Spacing.md) {
                ListingPhoto(urls: pickup.photo.map(listings.gridURLs) ?? [], placeholder: pickup.category.systemImage)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: AnaneoTheme.Radius.thumbnail, style: .continuous))
                VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.xs) {
                    Text(pickup.title)
                        .font(.headline)
                        .foregroundStyle(AnaneoTheme.ink)
                    Text(pickup.statusLine)
                        .font(.footnote.weight(pickup.needsYou ? .semibold : .regular))
                        .foregroundStyle(pickup.needsYou ? accent : AnaneoTheme.smoke)
                }
                Spacer(minLength: 0)
            }
            if let step = pickup.trackerStep {
                StageTracker(current: step, accent: accent)
            }
        }
        .card()
    }

    // MARK: - Giving

    @ViewBuilder
    private func givingSections(_ pickup: Pickup) -> some View {
        switch pickup.stage {
        case .open:
            section("Who asked", footer: "Choose one person. You can cancel and choose someone else if plans fall through.") {
                ForEach(pickup.requests) { request in
                    requesterRow(request, isGetting: false) {
                        Button("Reserve") { choosing = request }
                            .buttonStyle(.pill(.secondary, expanded: false))
                    }
                }
            }

        case .reserved:
            if let reservation = pickup.reservation, let handoff = reservation.handoff {
                section("Reserved for \(reservation.otherName)", footer: "Confirm once \(reservation.otherName) has it. When you've both confirmed, it counts toward your impact.") {
                    VStack(spacing: AnaneoTheme.Spacing.md) {
                        ConfirmationStatus(handoff: handoff, otherName: reservation.otherName)
                        if !handoff.confirmedByMe {
                            Button("Confirm Handoff", systemImage: "checkmark.circle") { confirmingHandoff = true }
                                .buttonStyle(.pill)
                        }
                        Button("Cancel Reservation", role: .destructive) { confirmingCancel = true }
                            .buttonStyle(.pill(.secondary))
                    }
                    .card()
                }

                let others = pickup.requests.filter { $0.id != reservation.id }
                if !others.isEmpty {
                    section("Also asked") {
                        ForEach(others) { requesterRow($0, isGetting: false) { EmptyView() } }
                    }
                }
            }

        case .done:
            if let reservation = pickup.reservation {
                completedSection(pickup, with: reservation)
            }

        case .unavailable:
            Text("This item isn't available.")
                .foregroundStyle(AnaneoTheme.smoke)
                .card()
        }
    }

    // MARK: - Getting

    @ViewBuilder
    private func gettingSections(_ pickup: Pickup) -> some View {
        let giver = pickup.requests.first?.otherName ?? "The giver"

        switch pickup.stage {
        case .open:
            section("Requested", footer: "\(giver) chooses who gets it from everyone who asks.") {
                Button("Withdraw Request", role: .destructive) { confirmingWithdraw = true }
                    .buttonStyle(.pill(.secondary))
            }

        case .reserved:
            if let handoff = pickup.reservation?.handoff {
                section("Reserved for you", footer: "Confirm once you have it. When you've both confirmed, it counts toward your impact.") {
                    VStack(spacing: AnaneoTheme.Spacing.md) {
                        ConfirmationStatus(handoff: handoff, otherName: giver)
                        if !handoff.confirmedByMe {
                            Button("Confirm Pickup", systemImage: "checkmark.circle") { confirmingHandoff = true }
                                .buttonStyle(.pill)
                        }
                        Button("Back Out", role: .destructive) { confirmingWithdraw = true }
                            .buttonStyle(.pill(.secondary))
                    }
                    .card()
                }
            }

        case .done:
            if let reservation = pickup.reservation {
                completedSection(pickup, with: reservation)
            }

        case .unavailable:
            section(nil, footer: "\(giver) gave it to someone else or took it down.") {
                Button("Remove from Pickups") { Task { await withdraw(pickup) } }
                    .buttonStyle(.pill(.secondary))
            }
        }
    }

    // MARK: - Shared

    /// One chat per request. Givers see the reservation first, then everyone else who asked.
    @ViewBuilder
    private func messagesSection(_ pickup: Pickup) -> some View {
        let reservation = pickup.reservation
        let requests = reservation.map { held in [held] + pickup.requests.filter { $0.id != held.id } } ?? pickup.requests
        if !requests.isEmpty {
            section("Messages") {
                ForEach(requests) { request in
                    NavigationLink {
                        ChatView(pickup: pickup, request: request)
                    } label: {
                        ChatLink(request: request, isGetting: !pickup.isGiver, summary: chat.summary(for: request))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func completedSection(_ pickup: Pickup, with reservation: PickupRequest) -> some View {
        section(nil, footer: "Thanks for keeping it moving.") {
            HStack(spacing: AnaneoTheme.Spacing.md) {
                LoopMark().frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pickup.isGiver ? "Given to \(reservation.otherName)" : "Received from \(reservation.otherName)")
                        .font(.headline)
                        .foregroundStyle(AnaneoTheme.ink)
                    if let completedAt = reservation.handoff?.completedAt {
                        Text(completedAt, format: .dateTime.month().day())
                            .font(.footnote)
                            .foregroundStyle(AnaneoTheme.smoke)
                    }
                }
                Spacer(minLength: 0)
            }
            .card()
        }
    }

    private func section<Content: View>(_ title: String?, footer: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.sm + 2) {
            if let title {
                Text(title).sectionLabel()
            }
            content()
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(AnaneoTheme.smoke)
            }
        }
    }

    private func requesterRow<Trailing: View>(_ request: PickupRequest, isGetting: Bool, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: AnaneoTheme.Spacing.md) {
            PersonBadge(name: request.otherName, isGetting: isGetting, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(request.otherName)
                    .font(.headline)
                    .foregroundStyle(AnaneoTheme.ink)
                Text("Asked \(request.requestedAt.formatted(.relative(presentation: .named)))")
                    .font(.footnote)
                    .foregroundStyle(AnaneoTheme.smoke)
            }
            Spacer(minLength: 0)
            trailing()
        }
        .card(padding: AnaneoTheme.Spacing.md)
    }

    private func perform(_ action: () async throws -> Void) async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// The pickup leaves the list afterward, so go back to it.
    private func withdraw(_ pickup: Pickup) async {
        await perform { try await pickups.withdraw(pickup) }
        if errorMessage == nil { dismiss() }
    }

    private func celebrate() {
        isCelebrating = true
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            isCelebrating = false
        }
    }
}

/// A request's chat, with its latest message and unread count.
private struct ChatLink: View {
    let request: PickupRequest
    let isGetting: Bool
    let summary: ChatSummary?

    var body: some View {
        HStack(spacing: AnaneoTheme.Spacing.md) {
            PersonBadge(name: request.otherName, isGetting: isGetting, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(request.otherName)
                    .font(.headline)
                    .foregroundStyle(AnaneoTheme.ink)
                Text(preview)
                    .font(.footnote)
                    .foregroundStyle(AnaneoTheme.smoke)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let unread = summary?.unreadCount, unread > 0 {
                Text(unread, format: .number)
                    .numerals(.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .frame(minWidth: 22)
                    .frame(height: 22)
                    .background(AnaneoTheme.clay, in: Capsule())
                    .accessibilityLabel("\(unread) unread messages")
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AnaneoTheme.smoke)
        }
        .card(padding: AnaneoTheme.Spacing.md)
    }

    private var preview: String {
        guard let summary else { return "Message \(request.otherName)" }
        return summary.lastSenderIsMe ? "You: \(summary.lastBody)" : summary.lastBody
    }
}

/// Who has confirmed so far.
private struct ConfirmationStatus: View {
    let handoff: Handoff
    let otherName: String

    var body: some View {
        VStack(spacing: AnaneoTheme.Spacing.sm) {
            row("You", confirmed: handoff.confirmedByMe)
            row(otherName, confirmed: handoff.confirmedByThem)
        }
    }

    private func row(_ who: String, confirmed: Bool) -> some View {
        HStack {
            Text(who)
                .foregroundStyle(AnaneoTheme.ink)
            Spacer()
            Label(confirmed ? "Confirmed" : "Not yet", systemImage: confirmed ? "checkmark.circle.fill" : "circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(confirmed ? AnaneoTheme.progress : AnaneoTheme.smoke)
        }
    }
}

#Preview {
    NavigationStack {
        PickupDetailView(itemID: Pickup.preview.id)
    }
    .environment(PickupService.preview([.preview]))
    .environment(ListingService())
    .environment(ChatService.preview())
}
