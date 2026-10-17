import SwiftUI

/// Open reports, oldest first, for moderators to dismiss, remove, or ban.
struct ModerationView: View {
    @Environment(SafetyService.self) private var safety
    @Environment(\.dismiss) private var dismiss

    @State private var cases: [ModerationCase] = []
    @State private var hasLoaded = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List(cases) { moderationCase in
                NavigationLink {
                    ModerationCaseView(moderationCase: moderationCase) {
                        cases.removeAll { $0.id == moderationCase.id }
                    }
                } label: {
                    ModerationRow(moderationCase: moderationCase)
                }
            }
            .overlay {
                if let errorMessage, cases.isEmpty {
                    ContentUnavailableView {
                        Label("Couldn't Load Reports", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try Again") { Task { await load() } }
                    }
                } else if !hasLoaded {
                    ProgressView()
                } else if cases.isEmpty {
                    ContentUnavailableView("Nothing to Review", systemImage: "checkmark.shield", description: Text("New reports show up here."))
                }
            }
            .navigationTitle("Moderation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        do {
            cases = try await safety.moderationQueue()
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
        hasLoaded = true
    }
}

private extension ReportTarget.Kind {
    var title: String {
        switch self {
        case .item: "Listing"
        case .message: "Message"
        case .user: "Person"
        }
    }

    var systemImage: String {
        switch self {
        case .item: "shippingbox"
        case .message: "bubble.left"
        case .user: "person"
        }
    }
}

private struct ModerationRow: View {
    let moderationCase: ModerationCase

    private var reportsText: String {
        let count = moderationCase.reportCount == 1 ? "1 report" : "\(moderationCase.reportCount) reports"
        return [count, moderationCase.reasons.first].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(moderationCase.summary ?? "Already deleted")
                    .lineLimit(1)
                Text(reportsText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: moderationCase.targetType.systemImage)
        }
    }
}

struct ModerationCaseView: View {
    @Environment(SafetyService.self) private var safety
    @Environment(ListingService.self) private var listings
    @Environment(\.dismiss) private var dismiss

    let moderationCase: ModerationCase
    /// Called after an action resolves the case, so the queue can drop it.
    let onResolved: () -> Void

    @State private var confirming: ModerationAction?
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var name: String { moderationCase.subjectName ?? "this person" }

    private var removeTitle: String {
        moderationCase.targetType == .item ? "Remove Listing" : "Delete Message"
    }

    var body: some View {
        List {
            Section(moderationCase.targetType.title) {
                if let photo = moderationCase.photo {
                    ListingPhoto(url: listings.photoURL(photo), placeholder: "shippingbox")
                        .frame(height: 200)
                        .listRowInsets(EdgeInsets())
                }
                Text(moderationCase.summary ?? "Already deleted")
                    .foregroundStyle(moderationCase.summary == nil ? Color.secondary : Color.primary)
                if let subjectName = moderationCase.subjectName, moderationCase.targetType != .user {
                    LabeledContent("Posted by", value: subjectName)
                }
                if moderationCase.subjectBanned {
                    Label("Banned", systemImage: "nosign")
                        .foregroundStyle(.red)
                }
                LabeledContent("First reported", value: moderationCase.firstReportedAt.formatted(.relative(presentation: .named)))
            }

            Section(moderationCase.reportCount == 1 ? "1 Report" : "\(moderationCase.reportCount) Reports") {
                ForEach(Array(moderationCase.reasons.enumerated()), id: \.offset) { _, reason in
                    Text(reason)
                }
            }

            Section {
                Button("Dismiss Reports") { Task { await perform(.dismiss) } }
                if moderationCase.targetType != .user, moderationCase.summary != nil {
                    Button(removeTitle, role: .destructive) { confirming = .remove }
                }
                if moderationCase.subjectID != nil, !moderationCase.subjectBanned {
                    Button("Ban \(name)", role: .destructive) { confirming = .ban }
                }
            } footer: {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else {
                    Text("Dismissing keeps the content up. Banning also removes \(name)'s open listings, ends their pickups in progress, and signs them out for good.")
                }
            }
        }
        .disabled(isWorking)
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            confirming == .ban ? "Ban \(name)?" : "\(removeTitle)?",
            isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
            titleVisibility: .visible,
            presenting: confirming
        ) { action in
            Button(action == .ban ? "Ban" : removeTitle, role: .destructive) {
                Task { await perform(action) }
            }
        } message: { action in
            Text(action == .ban ? "This can't be undone in the app." : "It will be gone for everyone.")
        }
    }

    private func perform(_ action: ModerationAction) async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await safety.moderate(moderationCase, action)
            onResolved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ModerationView()
        .environment(SafetyService())
        .environment(ListingService())
}
