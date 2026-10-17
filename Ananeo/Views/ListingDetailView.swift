import SwiftUI

struct ListingDetailView: View {
    @Environment(ListingService.self) private var listings
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    let listing: Listing

    @State private var confirmingRemove = false
    @State private var isRemoving = false
    @State private var errorMessage: String?

    private var isMine: Bool {
        if case .signedIn(let userID) = auth.state { userID == listing.ownerID } else { false }
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
                } else {
                    Button("Request Pickup", systemImage: "bubble.left.and.bubble.right") {}
                        .disabled(true)
                }
            } footer: {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else if !isMine {
                    Text("Messaging arrives in the next update.")
                }
            }
        }
        .navigationTitle(listing.title)
        .navigationBarTitleDisplayMode(.inline)
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
    .environment(AuthService())
}
