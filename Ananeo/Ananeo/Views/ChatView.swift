import SwiftUI

/// Chat between the giver and one requester, about one item. New messages arrive live.
/// The header carries the stage tracker, and a "Confirm" card appears while the item is reserved for this request.
struct ChatView: View {
    @Environment(ChatService.self) private var chat
    @Environment(PickupService.self) private var pickups
    @Environment(ListingService.self) private var listings

    /// The pickup as it was when the chat opened. The live one comes from the service.
    let pickup: Pickup
    let request: PickupRequest

    @State private var messages: [Message] = []
    @State private var hasLoaded = false
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var confirmingHandoff = false
    @State private var isConfirming = false
    @State private var isCelebrating = false

    private var livePickup: Pickup { pickups.pickup(for: pickup.id) ?? pickup }
    private var liveRequest: PickupRequest { livePickup.requests.first { $0.id == request.id } ?? request }
    private var name: String { request.otherName }

    /// Where this request is on the tracker. Reserved for someone else, or taken down, shows no tracker.
    private var trackerStep: Int? {
        if let handoff = liveRequest.handoff {
            return handoff.completedAt == nil ? 2 : StageTracker.pickupSteps.count
        }
        return livePickup.status == .available ? 0 : nil
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AnaneoTheme.Spacing.sm + 2) {
                ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                    if index == 0 || !Calendar.current.isDate(message.createdAt, inSameDayAs: messages[index - 1].createdAt) {
                        ChatDayLabel(date: message.createdAt)
                    }
                    ChatBubble(
                        message: message,
                        isMine: message.senderID != request.otherUserID,
                        otherName: name,
                        isGetting: !livePickup.isGiver
                    )
                }
                events
            }
            .padding(.horizontal, AnaneoTheme.Spacing.lg)
            .padding(.vertical, AnaneoTheme.Spacing.md)
        }
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
        .background(AnaneoTheme.canvas)
        .overlay {
            if !hasLoaded {
                LoopRing(progress: nil, lineWidth: 5).frame(width: 40)
            } else if messages.isEmpty && liveRequest.handoff == nil {
                ContentUnavailableView(
                    "No Messages Yet",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Sort out when and where to meet. Keep exact addresses until you've agreed on a time.")
                )
            }
        }
        .safeAreaInset(edge: .top) { header }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                confirmCard
                Composer(text: $draft, placeholder: "Message \(name)…", isSending: isSending, errorMessage: errorMessage) {
                    Task { await send() }
                }
            }
            .background(.bar)
        }
        .overlay {
            if isCelebrating {
                Celebration()
            }
        }
        .hidesFloatingTabBar()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            livePickup.isGiver ? "Did \(name) pick it up?" : "Did you get it?",
            isPresented: $confirmingHandoff,
            titleVisibility: .visible
        ) {
            Button(livePickup.isGiver ? "Yes, Handed Off" : "Yes, I Got It") {
                Task { await confirm() }
            }
        } message: {
            Text("Once you both confirm, it counts toward your impact. This can't be undone.")
        }
        .sensoryFeedback(trigger: isCelebrating) { _, playing in playing ? .success : nil }
        .onChange(of: liveRequest.handoff?.completedAt != nil) { wasDone, isDone in
            if isDone && !wasDone { celebrate() }
        }
        .task { await load() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: AnaneoTheme.Spacing.md) {
            HStack(spacing: AnaneoTheme.Spacing.md) {
                ListingPhoto(urls: livePickup.photo.map(listings.gridURLs) ?? [], placeholder: livePickup.category.systemImage)
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(livePickup.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AnaneoTheme.ink)
                        .lineLimit(1)
                    Text(headerLine)
                        .font(.caption)
                        .foregroundStyle(AnaneoTheme.smoke)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                PersonBadge(name: name, isGetting: !livePickup.isGiver, size: 32)
            }
            if let trackerStep {
                StageTracker(current: trackerStep, accent: livePickup.isGiver ? AnaneoTheme.progress : AnaneoTheme.sky)
            }
        }
        .padding(.horizontal, AnaneoTheme.Spacing.lg)
        .padding(.vertical, AnaneoTheme.Spacing.sm + 2)
        .background(.bar)
    }

    private var headerLine: String {
        if let handoff = liveRequest.handoff {
            if handoff.completedAt != nil { return "with \(name) · handed off" }
            return livePickup.isGiver ? "with \(name) · reserved for them" : "with \(name) · reserved for you"
        }
        if livePickup.status != .available { return "with \(name) · no longer available" }
        return "with \(name) · asked \(request.requestedAt.formatted(.relative(presentation: .named)))"
    }

    // MARK: - Events and confirmation

    /// What has happened on this request, after the messages. The database keeps no times for these,
    /// so they show the current state rather than a timeline.
    @ViewBuilder
    private var events: some View {
        if let handoff = liveRequest.handoff {
            SystemEventChip(text: livePickup.isGiver ? "You reserved it for \(name)" : "\(name) reserved it for you")
            if let completedAt = handoff.completedAt {
                SystemEventChip(text: "Handed off \(completedAt.formatted(.dateTime.month().day()))", systemImage: "checkmark.circle.fill")
            } else {
                if handoff.confirmedByThem {
                    SystemEventChip(text: "\(name) confirmed the handoff", systemImage: "checkmark")
                }
                if handoff.confirmedByMe {
                    SystemEventChip(text: "You confirmed the handoff", systemImage: "checkmark")
                }
            }
        }
    }

    @ViewBuilder
    private var confirmCard: some View {
        if let handoff = liveRequest.handoff, handoff.completedAt == nil, !handoff.confirmedByMe {
            let shape = RoundedRectangle(cornerRadius: AnaneoTheme.Radius.card, style: .continuous)
            HStack(spacing: AnaneoTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(livePickup.isGiver ? "Did \(name) pick it up?" : "Did you get it?")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AnaneoTheme.ink)
                    Text(handoff.confirmedByThem
                        ? "\(name) already confirmed. Once you do, it counts toward your impact."
                        : "Once you both confirm, it counts toward your impact.")
                        .font(.caption)
                        .foregroundStyle(AnaneoTheme.smoke)
                }
                Spacer(minLength: 0)
                Button("Confirm") { confirmingHandoff = true }
                    .buttonStyle(.pill(.primary, expanded: false))
                    .disabled(isConfirming)
            }
            .card(padding: AnaneoTheme.Spacing.md + 2)
            .overlay { shape.strokeBorder(AnaneoTheme.leaf, lineWidth: 1.5) }
            .padding(.horizontal, AnaneoTheme.Spacing.lg)
            .padding(.top, AnaneoTheme.Spacing.md)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Actions

    /// Loads the history, then appends new messages until the screen goes away.
    private func load() async {
        do {
            messages = try await chat.messages(in: request.id)
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
        hasLoaded = true
        await chat.markRead(request.id)

        await chat.listen(to: request.id) { message in
            guard append(message) else { return }
            if message.senderID == request.otherUserID {
                Task { await chat.markRead(request.id) }
            }
        }
    }

    private func send() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        errorMessage = nil
        isSending = true
        defer { isSending = false }
        do {
            append(try await chat.send(body, in: request.id))
            draft = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func confirm() async {
        guard let handoff = liveRequest.handoff else { return }
        errorMessage = nil
        isConfirming = true
        defer { isConfirming = false }
        do {
            try await pickups.confirm(handoff)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Both people confirmed: particles, a success haptic, and the loop closes on the tracker.
    private func celebrate() {
        isCelebrating = true
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            isCelebrating = false
        }
    }

    /// Your own messages come back over realtime too, so skip ones already shown.
    @discardableResult
    private func append(_ message: Message) -> Bool {
        guard !messages.contains(where: { $0.id == message.id }) else { return false }
        messages.append(message)
        return true
    }
}

#Preview {
    let pickup = Pickup.preview
    NavigationStack {
        ChatView(pickup: pickup, request: pickup.requests[0])
    }
    .environment(ChatService.preview())
    .environment(PickupService.preview([pickup]))
    .environment(ListingService())
}
