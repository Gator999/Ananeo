import SwiftUI

struct ImpactView: View {
    @Environment(ItemStore.self) private var store
    @Environment(AuthService.self) private var auth
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        ImpactStat(value: "\(store.exchangedItems.count)", label: "Items passed on")
                        Divider()
                        ImpactStat(value: String(format: "%.1f kg", store.kilogramsDiverted), label: "Waste diverted")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                Section("Completed exchanges") {
                    if store.exchangedItems.isEmpty {
                        Text("Nothing yet. Report an exchange from an item's page.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.exchangedItems) { item in
                        Label(item.title, systemImage: item.category.systemImage)
                    }
                }
            }
            .navigationTitle("Your Impact")
            .toolbar {
                Menu {
                    Button("Sign Out") {
                        Task { await auth.signOut() }
                    }
                    Button("Delete Account", role: .destructive) {
                        confirmingDelete = true
                    }
                } label: {
                    Label("Account", systemImage: "person.crop.circle")
                }
            }
            .confirmationDialog("Delete your account?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete Account", role: .destructive) {
                    Task { await auth.deleteAccount() }
                }
            } message: {
                Text("Your listings, messages, and impact history will be permanently removed.")
            }
        }
    }
}

private struct ImpactStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack {
            Text(value).font(.largeTitle.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ImpactView()
        .environment(ItemStore())
        .environment(AuthService())
}
