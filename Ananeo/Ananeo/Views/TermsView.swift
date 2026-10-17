import SwiftUI

/// Shown after sign-in until the person accepts the current terms of use.
struct TermsAcceptanceView: View {
    @Environment(TermsService.self) private var terms
    @Environment(AuthService.self) private var auth

    let userID: UUID

    @State private var isAccepting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                TermsContent()
                    .padding()
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Text("By tapping I Agree, you accept these terms, including zero tolerance for objectionable content and abusive behavior.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Button {
                        Task { await accept() }
                    } label: {
                        Group {
                            if isAccepting { ProgressView() } else { Text("I Agree").bold() }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isAccepting)
                    Button("Sign Out") { Task { await auth.signOut() } }
                        .font(.subheadline)
                }
                .padding()
                .background(.bar)
            }
            .navigationTitle("Terms of Use")
        }
    }

    private func accept() async {
        errorMessage = nil
        isAccepting = true
        defer { isAccepting = false }
        do {
            try await terms.accept(userID: userID)
        } catch {
            errorMessage = "Couldn't save that: \(error.localizedDescription)"
        }
    }
}

/// The terms, to read again later from the account menu.
struct TermsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                TermsContent()
                    .padding()
            }
            .navigationTitle("Terms of Use")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// The prohibited-items list on its own, for the Give form.
struct ProhibitedItemsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(TermsOfUse.prohibitedItems, id: \.self) { item in
                        Text(item)
                    }
                } footer: {
                    Text("Only list physical items you own and have the right to give away. Listings that break these rules are removed, and people who keep posting them are banned.")
                }
            }
            .navigationTitle("What You Can't List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// The full text of the terms.
struct TermsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Last updated \(TermsOfUse.lastUpdated)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(TermsOfUse.sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.headline)
                    ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                        switch block {
                        case .paragraph(let text):
                            Text(text)
                        case .bullets(let items):
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(items, id: \.self) { item in
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text("•")
                                        Text(item)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    TermsAcceptanceView(userID: UUID())
        .environment(TermsService())
        .environment(AuthService())
}
