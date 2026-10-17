import SwiftUI

struct ListingDetailView: View {
    @Environment(ListingService.self) private var listings
    @Environment(PickupService.self) private var pickups
    @Environment(AuthService.self) private var auth
    @Environment(SafetyService.self) private var safety
    @Environment(\.dismiss) private var dismiss

    let listing: Listing

    @State private var confirmingRemove = false
    @State private var isRemoving = false
    @State private var isRequesting = false
    @State private var reporting: ReportTarget?
    @State private var confirmingBlock = false
    @State private var errorMessage: String?

    private var isMine: Bool {
        if case .signedIn(let userID) = auth.state { userID == listing.ownerID } else { false }
    }

    private var hasRequested: Bool {
        pickups.pickup(for: listing.id)?.isGiver == false
    }

    /// For the owner: how many people have asked for this item.
    private var requestCount: Int {
        isMine ? pickups.pickup(for: listing.id)?.requests.count ?? 0 : 0
    }

    var body: some View {
        List {
            Section {
                photoPager
                    .listRowInsets(EdgeInsets())
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(listing.title).font(.title2.bold())
                    HStack(spacing: 8) {
                        Badge(text: listing.mode.title)
                        Badge(text: listing.condition.title)
                    }
                    if !listing.details.isEmpty {
                        Text(listing.details).padding(.top, 4)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Details") {
                LabeledContent("Category", value: listing.category.title)
                if let miles = listing.distanceMiles {
                    LabeledContent("Distance", value: Distance.label(miles: miles))
                }
                if let wants = listing.wants {
                    LabeledContent("Wants in return", value: wants)
                }
                LabeledContent("Listed", value: listing.createdAt.formatted(.relative(presentation: .named)))
            }

            Section {
                if isMine {
                    Button("Remove Listing", role: .destructive) { confirmingRemove = true }
                        .disabled(isRemoving)
                } else if safety.isBlocked(listing.ownerID) {
                    Label("You blocked this person", systemImage: "hand.raised")
                        .foregroundStyle(.secondary)
                } else if hasRequested {
                    Label("Requested", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                } else {
                    Button("Request Pickup", systemImage: "hand.raised") {
                        Task { await request() }
                    }
                    .disabled(isRequesting)
                }
            } footer: {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else if requestCount > 0 {
                    Text(requestCount == 1 ? "1 person asked for this. Choose who gets it in Pickups." : "\(requestCount) people asked for this. Choose who gets it in Pickups.")
                } else if hasRequested {
                    Text("Follow along in Pickups. If the giver chooses you, you'll both confirm the handoff there.")
                } else if !isMine && !safety.isBlocked(listing.ownerID) {
                    Text("The giver chooses who gets it from everyone who asks.")
                }
            }
        }
        .navigationTitle(listing.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isMine {
                Menu {
                    Button("Report Listing", systemImage: "flag") {
                        reporting = ReportTarget(kind: .item, id: listing.id, userID: listing.ownerID, name: nil)
                    }
                    if !safety.isBlocked(listing.ownerID) {
                        Button("Block This Person", systemImage: "hand.raised", role: .destructive) { confirmingBlock = true }
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $reporting) { ReportView(target: $0) }
        .confirmationDialog("Block this person?", isPresented: $confirmingBlock, titleVisibility: .visible) {
            Button("Block", role: .destructive) { Task { await block() } }
        } message: {
            Text("You won't see each other's listings or be able to message each other, and any pickup in progress between you ends.")
        }
        .confirmationDialog("Remove this listing?", isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button("Remove Listing", role: .destructive) { Task { await remove() } }
        } message: {
            Text("It will no longer be visible to anyone.")
        }
    }

    @ViewBuilder
    private var photoPager: some View {
        let urls = listing.photos.compactMap(listings.photoURL)
        if urls.isEmpty {
            ListingPhoto(url: nil, placeholder: listing.category.systemImage)
                .frame(height: 260)
        } else {
            TabView {
                ForEach(urls, id: \.self) { url in
                    ListingPhoto(url: url, placeholder: listing.category.systemImage)
                        .frame(maxWidth: .infinity)
                        .frame(height: 320)
                        .clipped()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .always : .never))
            .frame(height: 320)
        }
    }

    private func request() async {
        errorMessage = nil
        isRequesting = true
        defer { isRequesting = false }
        do {
            try await pickups.request(listing)
        } catch {
            errorMessage = "Couldn't send your request: \(error.localizedDescription)"
        }
    }

    private func block() async {
        do {
            try await safety.block(listing.ownerID)
        } catch {
            errorMessage = "Couldn't block: \(error.localizedDescription)"
        }
    }

    private func remove() async {
        isRemoving = true
        defer { isRemoving = false }
        do {
            try await listings.remove(listing)
            dismiss()
        } catch {
            errorMessage = "Couldn't remove: \(error.localizedDescription)"
        }
    }
}

private struct Badge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.tint.opacity(0.15), in: Capsule())
    }
}

#Preview {
    NavigationStack {
        ListingDetailView(listing: .preview)
    }
    .environment(ListingService())
    .environment(PickupService())
    .environment(AuthService())
    .environment(SafetyService())
}
