import SwiftUI

/// Report a listing, a message, or a person, and optionally block whoever is responsible.
struct ReportView: View {
    @Environment(SafetyService.self) private var safety
    @Environment(\.dismiss) private var dismiss

    let target: ReportTarget

    @State private var reason: ReportReason?
    @State private var details = ""
    @State private var alsoBlock: Bool
    @State private var isSending = false
    @State private var isSent = false
    @State private var errorMessage: String?

    init(target: ReportTarget) {
        self.target = target
        // Someone reporting a person or a message usually wants distance. A listing, not always.
        _alsoBlock = State(initialValue: target.kind != .item)
    }

    private var title: String {
        switch target.kind {
        case .item: "Report Listing"
        case .message: "Report Message"
        case .user: "Report \(target.name ?? "Person")"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isSent {
                    ContentUnavailableView {
                        Label("Thanks for Telling Us", systemImage: "checkmark.shield")
                    } description: {
                        Text("We review every report within 24 hours.")
                    } actions: {
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    form
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var form: some View {
        Form {
            Section("What's Wrong?") {
                Picker("Reason", selection: $reason) {
                    ForEach(ReportReason.allCases) { reason in
                        Text(reason.title).tag(Optional(reason))
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section("Details") {
                TextField("Optional. Anything that helps us review it.", text: $details, axis: .vertical)
                    .lineLimit(3...6)
            }

            if !safety.isBlocked(target.userID) {
                Section {
                    Toggle("Also block \(target.name ?? "this person")", isOn: $alsoBlock)
                } footer: {
                    Text("You won't see each other's listings or be able to message each other, and any pickup in progress between you ends.")
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
        }
        .disabled(isSending)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Send") { Task { await send() } }
                    .disabled(reason == nil || isSending)
            }
        }
    }

    private func send() async {
        guard let reason else { return }
        errorMessage = nil
        isSending = true
        defer { isSending = false }
        do {
            try await safety.report(target, reason: reason, details: details)
            if alsoBlock && !safety.isBlocked(target.userID) {
                try await safety.block(target.userID)
            }
            isSent = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ReportView(target: ReportTarget(kind: .user, id: UUID(), userID: UUID(), name: "Sam"))
        .environment(SafetyService())
}
