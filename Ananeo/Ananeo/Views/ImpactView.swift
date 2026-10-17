import SwiftUI

/// Personal and community totals, counted only from handoffs both sides confirmed.
struct ImpactView: View {
    @Environment(ListingService.self) private var listings
    @Environment(AuthService.self) private var auth

    @State private var mine = Impact()
    @State private var community = CommunityImpact()
    @State private var errorMessage: String?
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        ImpactStat(value: "\(mine.itemsGiven)", label: "Items given")
                        Divider()
                        ImpactStat(value: "\(mine.itemsReceived)", label: "Items received")
                        Divider()
                        ImpactStat(value: String(format: "%.1f kg", mine.kgDiverted), label: "Kept from landfill")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                } header: {
                    Text("You")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    } else if mine.itemsGiven + mine.itemsReceived == 0 {
                        Text("Your totals grow each time a handoff is confirmed by both people.")
                    }
                }

                Section("Everyone on Ananeo") {
                    HStack {
                        ImpactStat(value: "\(community.itemsKeptMoving)", label: "Items kept moving")
                        Divider()
                        ImpactStat(value: String(format: "%.0f kg", community.kgDiverted), label: "Kept from landfill")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
            }
            .navigationTitle("Your Impact")
            .refreshable { await load() }
            .task(id: listings.revision) { await load() }
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

    private func load() async {
        do {
            async let mineResult = listings.myImpact()
            async let communityResult = listings.communityImpact()
            (mine, community) = try await (mineResult, communityResult)
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = "Couldn't load totals: \(error.localizedDescription)"
        }
    }
}

private struct ImpactStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack {
            Text(value).font(.title.bold()).minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ImpactView()
        .environment(ListingService())
        .environment(AuthService())
}
