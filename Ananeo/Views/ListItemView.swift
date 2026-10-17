import CoreLocation
import PhotosUI
import SwiftUI

/// The Give tab: photograph something, describe it, and post it to people nearby.
struct ListItemView: View {
    @Environment(ListingService.self) private var listings
    @Environment(LocationService.self) private var location

    @State private var draft = ListingDraft()
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var photos: [Data] = []
    @State private var isLoadingPhotos = false
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var didPost = false

    private var coordinate: CLLocationCoordinate2D? {
        if case .ready(let coordinate) = location.status { coordinate } else { nil }
    }

    private var canPost: Bool {
        !draft.trimmedTitle.isEmpty && !photos.isEmpty && coordinate != nil && !isPosting && !isLoadingPhotos
    }

    var body: some View {
        NavigationStack {
            Form {
                photosSection

                Section("What is it?") {
                    TextField("Title", text: $draft.title)
                    TextField("Description, size, any flaws", text: $draft.details, axis: .vertical)
                        .lineLimit(3...6)
                    Picker("Category", selection: $draft.category) {
                        ForEach(ItemCategory.allCases) { category in
                            Label(category.title, systemImage: category.systemImage).tag(category)
                        }
                    }
                    Picker("Condition", selection: $draft.condition) {
                        ForEach(ItemCondition.allCases) { Text($0.title).tag($0) }
                    }
                }

                Section("Offer") {
                    Picker("Offer", selection: $draft.mode) {
                        ForEach(ItemMode.allCases) { Text($0.pickerTitle).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if draft.mode == .swap {
                        TextField("What would you like in return?", text: $draft.wants)
                    }
                }

                pickupSection

                Section {
                    Button {
                        Task { await post() }
                    } label: {
                        HStack {
                            Spacer()
                            if isPosting { ProgressView() } else { Text("Post Item").bold() }
                            Spacer()
                        }
                    }
                    .disabled(!canPost)
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    } else if photos.isEmpty {
                        Text("Add at least one photo.")
                    }
                }
            }
            .navigationTitle("Give")
            .alert("Posted", isPresented: $didPost) {
                Button("OK") {}
            } message: {
                Text("Your item is now visible to people nearby.")
            }
            .onChange(of: pickerItems) { _, items in
                Task { await loadPhotos(items) }
            }
        }
    }

    // MARK: - Sections

    private var photosSection: some View {
        Section {
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(photos.enumerated()), id: \.offset) { index, data in
                            PhotoThumbnail(data: data) {
                                pickerItems.remove(at: index)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: ListingService.maxPhotos,
                selectionBehavior: .ordered,
                matching: .images
            ) {
                HStack {
                    Label(photos.isEmpty ? "Add Photos" : "Change Photos", systemImage: "photo.on.rectangle.angled")
                    if isLoadingPhotos {
                        Spacer()
                        ProgressView()
                    }
                }
            }
        } header: {
            Text("Photos")
        } footer: {
            Text("Up to \(ListingService.maxPhotos). The first one is the cover.")
        }
    }

    @ViewBuilder
    private var pickupSection: some View {
        Section {
            switch location.status {
            case .ready:
                Label("Shown as an approximate area, within about ¼ mile of where you are now.", systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
            case .locating:
                HStack {
                    ProgressView()
                    Text("Finding your area…").foregroundStyle(.secondary)
                }
            case .needsPermission:
                Button("Use My Location", systemImage: "location") { location.request() }
            case .denied:
                Button("Allow Location in Settings", systemImage: "gear") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        } header: {
            Text("Pickup Area")
        } footer: {
            Text("Your exact address is never shown. Share it in a message only when you're ready.")
        }
    }

    // MARK: - Actions

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        isLoadingPhotos = true
        defer { isLoadingPhotos = false }
        var loaded: [Data] = []
        for item in items {
            guard let raw = try? await item.loadTransferable(type: Data.self) else { continue }
            let prepared = await Task.detached(priority: .userInitiated) {
                ListingService.preparePhoto(raw)
            }.value
            if let prepared { loaded.append(prepared) }
        }
        // Ignore stale results if the selection changed while loading.
        if items == pickerItems { photos = loaded }
    }

    private func post() async {
        guard let coordinate else { return }
        errorMessage = nil
        isPosting = true
        defer { isPosting = false }
        do {
            try await listings.create(draft, photos: photos, at: coordinate)
            draft = ListingDraft()
            pickerItems = []
            photos = []
            didPost = true
        } catch {
            errorMessage = "Couldn't post: \(error.localizedDescription)"
        }
    }
}

private struct PhotoThumbnail: View {
    let data: Data
    let onRemove: () -> Void

    var body: some View {
        Group {
            if let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.secondary.opacity(0.2)
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .topTrailing) {
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .padding(4)
            .accessibilityLabel("Remove photo")
        }
    }
}

#Preview {
    ListItemView()
        .environment(ListingService())
        .environment(LocationService())
}
