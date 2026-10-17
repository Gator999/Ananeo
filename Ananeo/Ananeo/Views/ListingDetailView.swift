import SwiftUI

struct ListingDetailView: View {
    @Environment(ListingService.self) private var listings
    @Environment(PickupService.self) private var pickups
    @Environment(ChatService.self) private var chat
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    let listing: Listing

    @State private var confirmingRemove = false
    @State private var isRemoving = false
    @State private var isRequesting = false
    @State private var composingRequest = false
    @State private var requestNote = ""
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
                } else if hasRequested {
                    Label("Requested", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                } else {
                    Button("Request Pickup", systemImage: "hand.raised") { composingRequest = true }
                        .disabled(isRequesting)
                }
            } footer: {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else if requestCount > 0 {
                    Text(requestCount == 1 ? "1 person asked for this. Choose who gets it in Pickups." : "\(requestCount) people asked for this. Choose who gets it in Pickups.")
                } else if hasRequested {
                    Text("Message the giver and follow along in Pickups. If they choose you, you'll both confirm the handoff there.")
                } else if !isMine {
                    Text("The giver chooses who gets it from everyone who asks.")
                }
            }
        }
        .navigationTitle(listing.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Request Pickup", isPresented: $composingRequest) {
            TextField("Message (optional)", text: $requestNote)
            Button("Send Request") { Task { await request() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Say when you could pick it up. The giver sees this with your request.")
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
        let note = requestNote.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil
        isRequesting = true
        defer { isRequesting = false }
        let conversationID: UUID
        do {
            conversationID = try await pickups.request(listing)
            requestNote = ""
        } catch {
            errorMessage = "Couldn't send your request: \(error.localizedDescription)"
            return
        }
        guard !note.isEmpty else { return }
        do {
            try await chat.send(String(note.prefix(ChatService.maxLength)), in: conversationID)
        } catch {
            errorMessage = "Your request went through, but the message didn't: \(error.localizedDescription)"
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
    .environment(ChatService())
    .environment(AuthService())
}
