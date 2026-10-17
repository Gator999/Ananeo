import SwiftUI

/// Everyone the signed-in user has blocked, with a way to unblock them.
struct BlockedPeopleView: View {
    @Environment(SafetyService.self) private var safety
    @Environment(\.dismiss) private var dismiss

    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(safety.blocked) { person in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.name)
                                Text("Blocked \(person.blockedAt.formatted(.relative(presentation: .named)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Unblock") { Task { await unblock(person) } }
                                .buttonStyle(.bordered)
                        }
                    }
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    } else if !safety.blocked.isEmpty {
                        Text("Unblocking lets you see each other's listings and message again. Pickups that ended don't come back.")
                    }
                }
            }
            .overlay {
                if safety.blocked.isEmpty {
                    ContentUnavailableView(
                        "No One Blocked",
                        systemImage: "hand.raised",
                        description: Text("Block someone from a listing or a chat, and they'll show up here.")
                    )
                }
            }
            .navigationTitle("Blocked People")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .refreshable { try? await safety.refresh() }
            .task { try? await safety.refresh() }
        }
    }

    private func unblock(_ person: BlockedPerson) async {
        do {
            try await safety.unblock(person.id)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't unblock: \(error.localizedDescription)"
        }
    }
}

#Preview {
    BlockedPeopleView()
        .environment(SafetyService())
}
