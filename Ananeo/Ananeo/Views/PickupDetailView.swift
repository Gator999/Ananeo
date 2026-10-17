import SwiftUI

/// One pickup from either side: choose who gets it, confirm the handoff, or step back.
struct PickupDetailView: View {
    @Environment(PickupService.self) private var pickups
    @Environment(ListingService.self) private var listings
    @Environment(\.dismiss) private var dismiss

    let itemID: UUID

    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var choosing: PickupRequest?
    @State private var confirmingHandoff = false
    @State private var confirmingCancel = false
    @State private var confirmingWithdraw = false

    var body: some View {
        if let pickup = pickups.pickup(for: itemID) {
            content(pickup)
        } else {
            ContentUnavailableView("No Longer in Pickups", systemImage: "tray")
        }
    }

    private func content(_ pickup: Pickup) -> some View {
        let name = pickup.reservation?.otherName ?? pickup.requests.first?.otherName ?? "them"

        return List {
            Section {
                HStack(spacing: 12) {
                    ListingPhoto(url: pickup.photo.flatMap(listings.photoURL), placeholder: pickup.category.systemImage)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pickup.title).font(.headline)
                        Text(pickup.category.title).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }

            if pickup.isGiver {
                givingSections(pickup)
            } else {
                gettingSections(pickup)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(pickup.title)
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isWorking)
        .refreshable { try? await pickups.refresh() }
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

    // MARK: - Giving

    @ViewBuilder
    private func givingSections(_ pickup: Pickup) -> some View {
        switch pickup.stage {
        case .open:
            Section {
                ForEach(pickup.requests) { request in
                    NavigationLink {
                        ChatView(conversationID: request.id, otherName: request.otherName)
                    } label: {
                        HStack {
                            RequesterLabel(request: request)
                            Spacer()
                            Button("Reserve") { choosing = request }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            } header: {
                Text("Who Asked")
            } footer: {
                Text("Tap someone to message them. Choose one person; you can cancel and choose someone else if plans fall through.")
            }

        case .reserved:
            if let reservation = pickup.reservation, let handoff = reservation.handoff {
                Section {
                    chatLink(reservation)
                    ConfirmationStatus(handoff: handoff, otherName: reservation.otherName)
                    if !handoff.confirmedByMe {
                        Button("Confirm Handoff", systemImage: "checkmark.circle") { confirmingHandoff = true }
                    }
                    Button("Cancel Reservation", role: .destructive) { confirmingCancel = true }
                } header: {
                    Text("Reserved for \(reservation.otherName)")
                } footer: {
                    Text("Confirm once \(reservation.otherName) has it. When you've both confirmed, it counts toward your impact.")
                }

                let others = pickup.requests.filter { $0.id != reservation.id }
                if !others.isEmpty {
                    Section("Also Asked") {
                        ForEach(others) { request in
                            NavigationLink {
                                ChatView(conversationID: request.id, otherName: request.otherName)
                            } label: {
                                RequesterLabel(request: request)
                            }
                        }
                    }
                }
            }

        case .done:
            if let reservation = pickup.reservation {
                completedSection(pickup, with: reservation)
            }

        case .unavailable:
            Section {
                Text("This item isn't available.")
            }
        }
    }

    // MARK: - Getting

    @ViewBuilder
    private func gettingSections(_ pickup: Pickup) -> some View {
        let giver = pickup.requests.first?.otherName ?? "The giver"

        if let request = pickup.requests.first {
            Section {
                chatLink(request)
            }
        }

        switch pickup.stage {
        case .open:
            Section {
                Button("Withdraw Request", role: .destructive) { confirmingWithdraw = true }
            } header: {
                Text("Requested")
            } footer: {
                Text("\(giver) chooses who gets it from everyone who asks.")
            }

        case .reserved:
            if let handoff = pickup.reservation?.handoff {
                Section {
                    ConfirmationStatus(handoff: handoff, otherName: giver)
                    if !handoff.confirmedByMe {
                        Button("Confirm Pickup", systemImage: "checkmark.circle") { confirmingHandoff = true }
                    }
                    Button("Back Out", role: .destructive) { confirmingWithdraw = true }
                } header: {
                    Text("Reserved for You")
                } footer: {
                    Text("Confirm once you have it. When you've both confirmed, it counts toward your impact.")
                }
            }

        case .done:
            if let reservation = pickup.reservation {
                completedSection(pickup, with: reservation)
            }

        case .unavailable:
            Section {
                Button("Remove from Pickups") { Task { await withdraw(pickup) } }
            } footer: {
                Text("\(giver) gave it to someone else or took it down.")
            }
        }
    }

    // MARK: - Shared

    private func chatLink(_ request: PickupRequest) -> some View {
        NavigationLink {
            ChatView(conversationID: request.id, otherName: request.otherName)
        } label: {
            HStack {
                Label("Message \(request.otherName)", systemImage: "bubble.left.and.bubble.right")
                Spacer()
                UnreadBadge(count: request.unreadCount)
            }
        }
    }

    private func completedSection(_ pickup: Pickup, with reservation: PickupRequest) -> some View {
        Section {
            if pickup.isGiver {
                chatLink(reservation)
            }
            if let completedAt = reservation.handoff?.completedAt {
                LabeledContent(pickup.isGiver ? "Given to \(reservation.otherName)" : "Received from \(reservation.otherName)") {
                    Text(completedAt, format: .dateTime.month().day())
                }
            }
        } footer: {
            Text("Thanks for keeping it moving.")
        }
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
}

private struct RequesterLabel: View {
    let request: PickupRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(request.otherName)
                UnreadBadge(count: request.unreadCount)
            }
            Group {
                if let lastMessage = request.lastMessage {
                    Text(request.lastMessageIsMine ? "You: \(lastMessage)" : lastMessage)
                } else {
                    Text("Asked \(request.requestedAt.formatted(.relative(presentation: .named)))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }
}

/// Who has confirmed so far.
private struct ConfirmationStatus: View {
    let handoff: Handoff
    let otherName: String

    var body: some View {
        Group {
            row("You", confirmed: handoff.confirmedByMe)
            row(otherName, confirmed: handoff.confirmedByThem)
        }
    }

    private func row(_ who: String, confirmed: Bool) -> some View {
        LabeledContent(who) {
            Label(confirmed ? "Confirmed" : "Not yet", systemImage: confirmed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(confirmed ? Color.accentColor : Color.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        PickupDetailView(itemID: Pickup.preview.id)
    }
    .environment(PickupService.preview([.preview]))
    .environment(ListingService())
    .environment(ChatService.preview([]))
    .environment(AuthService())
}
