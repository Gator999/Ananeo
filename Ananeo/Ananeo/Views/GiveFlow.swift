import CoreLocation
import PhotosUI
import SwiftUI

/// Give something in three steps: Snap, Describe, Post. Opens full screen from the Give button.
struct GiveFlow: View {
    @Environment(ListingService.self) private var listings
    @Environment(LocationService.self) private var location
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Called after a successful post, once the form has been cleared. The presenter dismisses the flow.
    var onPosted: () -> Void = {}

    enum Step: Int, CaseIterable {
        case snap, describe, post

        var title: String {
            switch self {
            case .snap: "Snap it"
            case .describe: "Describe it"
            case .post: "Post it"
            }
        }

        var name: String {
            switch self {
            case .snap: "Snap"
            case .describe: "Describe"
            case .post: "Post"
            }
        }
    }

    @State private var step: Step = .snap
    @State private var draft = ListingDraft()
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var photos: [PickedPhoto] = []
    @State private var showingProhibited = false
    @State private var isLoadingPhotos = false
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var confirmingCancel = false
    @FocusState private var isTitleFocused: Bool

    private var coordinate: CLLocationCoordinate2D? {
        if case .ready(let coordinate) = location.status { coordinate } else { nil }
    }

    private var hasChanges: Bool {
        !photos.isEmpty || !draft.trimmedTitle.isEmpty || !draft.details.isEmpty
    }

    private var canContinue: Bool {
        switch step {
        case .snap: !photos.isEmpty && !isLoadingPhotos
        case .describe: !draft.trimmedTitle.isEmpty
        case .post: coordinate != nil && !isPosting
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.xl) {
                    stepHeader
                    stepContent
                        .id(step)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
                .padding(.horizontal, AnaneoTheme.Spacing.xl)
                .padding(.bottom, AnaneoTheme.Spacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AnaneoTheme.canvas)
            .safeAreaInset(edge: .bottom) { footer }
            .navigationTitle("Give something")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges { confirmingCancel = true } else { dismiss() }
                    }
                    .disabled(isPosting)
                }
            }
            .confirmationDialog("Discard this listing?", isPresented: $confirmingCancel, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { dismiss() }
            }
            .sheet(isPresented: $showingProhibited) { ProhibitedItemsSheet() }
            .onChange(of: pickerItems) { _, items in
                Task { await loadPhotos(items) }
            }
            .animation(AnaneoMotion.settle(reduceMotion: reduceMotion), value: step)
        }
        .interactiveDismissDisabled(hasChanges)
    }

    // MARK: - Header and footer

    private var stepHeader: some View {
        HStack(spacing: AnaneoTheme.Spacing.md) {
            LoopRing(progress: Double(step.rawValue + 1) / Double(Step.allCases.count), lineWidth: 6)
                .frame(width: 44)
                .overlay {
                    Text("\(step.rawValue + 1)")
                        .numerals(.subheadline)
                        .foregroundStyle(AnaneoTheme.ink)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(AnaneoTheme.ink)
                crumbs
                    .font(.footnote)
                    .foregroundStyle(AnaneoTheme.smoke)
            }
        }
        .padding(.top, AnaneoTheme.Spacing.sm)
        .accessibilityElement(children: .combine)
    }

    /// "Step 2 of 3 · Snap, Describe, Post", with the current step in Ink.
    private var crumbs: Text {
        var text = Text("Step \(step.rawValue + 1) of \(Step.allCases.count) · ")
        for (index, candidate) in Step.allCases.enumerated() {
            let name = Text(candidate.name)
            text = text + (candidate == step ? name.bold().foregroundStyle(AnaneoTheme.ink) : name)
            if index < Step.allCases.count - 1 {
                text = text + Text(", ")
            }
        }
        return text
    }

    private var footer: some View {
        HStack(spacing: AnaneoTheme.Spacing.md) {
            if let previous = Step(rawValue: step.rawValue - 1) {
                Button("Back") { step = previous }
                    .buttonStyle(.pill(.secondary, expanded: false))
                    .disabled(isPosting)
            }
            Button {
                advance()
            } label: {
                if isPosting {
                    LoopRing(progress: nil, lineWidth: 3, style: .white, showsTrack: false)
                        .frame(width: 24)
                } else if step == .post {
                    Label("Post Item", systemImage: "paperplane.fill")
                } else {
                    Label(step == .snap ? "Next: describe it" : "Next: pickup area", systemImage: "arrow.right")
                }
            }
            .buttonStyle(.pill)
            .disabled(!canContinue)
        }
        .padding(.horizontal, AnaneoTheme.Spacing.xl)
        .padding(.top, AnaneoTheme.Spacing.md)
        .padding(.bottom, AnaneoTheme.Spacing.sm)
        .background(.bar)
    }

    private func advance() {
        switch step {
        case .snap:
            step = .describe
        case .describe:
            isTitleFocused = false
            step = .post
        case .post:
            Task { await post() }
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .snap: snapStep
        case .describe: describeStep
        case .post: postStep
        }
    }

    private var snapStep: some View {
        VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.lg) {
            Text("Photos").sectionLabel()
            if photos.isEmpty {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: ListingService.maxPhotos, selectionBehavior: .ordered, matching: .images) {
                    VStack(spacing: AnaneoTheme.Spacing.sm) {
                        Image(systemName: "camera.fill")
                            .font(.largeTitle)
                        Text("Add photos")
                            .font(.headline)
                    }
                    .foregroundStyle(AnaneoTheme.leaf)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .background(AnaneoTheme.leaf.opacity(0.08), in: RoundedRectangle(cornerRadius: AnaneoTheme.Radius.card, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AnaneoTheme.Radius.card, style: .continuous)
                            .strokeBorder(AnaneoTheme.leaf.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    }
                    .overlay {
                        if isLoadingPhotos {
                            LoopRing(progress: nil, lineWidth: 5).frame(width: 40)
                        }
                    }
                }
            } else {
                photoStrip
            }
            Text("Up to \(ListingService.maxPhotos). The first one is the cover. Photos are resized and location data is removed before upload.")
                .font(.footnote)
                .foregroundStyle(AnaneoTheme.smoke)
        }
    }

    /// The chosen photos with the cover marked, and an Add tile while there is room.
    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AnaneoTheme.Spacing.sm + 2) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    PhotoThumbnail(data: photo.data, isCover: index == 0) { remove(photo) }
                }
                if photos.count < ListingService.maxPhotos {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: ListingService.maxPhotos, selectionBehavior: .ordered, matching: .images) {
                        VStack(spacing: AnaneoTheme.Spacing.xs) {
                            Image(systemName: "plus").font(.title3.weight(.bold))
                            Text("Add").font(.caption.weight(.bold))
                        }
                        .foregroundStyle(AnaneoTheme.leaf)
                        .frame(width: 84, height: 84)
                        .overlay {
                            RoundedRectangle(cornerRadius: AnaneoTheme.Radius.thumbnail, style: .continuous)
                                .strokeBorder(AnaneoTheme.smoke.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        }
                        .overlay {
                            if isLoadingPhotos {
                                LoopRing(progress: nil, lineWidth: 3).frame(width: 24)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, AnaneoTheme.Spacing.xs)
        }
        .scrollClipDisabled()
    }

    private var describeStep: some View {
        VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.xl) {
            photoStrip

            VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.sm + 2) {
                Text("What is it?").sectionLabel()
                TextField("Title", text: $draft.title)
                    .font(.title3.weight(.bold))
                    .focused($isTitleFocused)
                    .submitLabel(.next)
                    .padding(.horizontal, AnaneoTheme.Spacing.lg)
                    .frame(minHeight: AnaneoTheme.Size.pillButton)
                    .background(AnaneoTheme.surface, in: RoundedRectangle(cornerRadius: AnaneoTheme.Radius.tile, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AnaneoTheme.Radius.tile, style: .continuous)
                            .strokeBorder(isTitleFocused ? AnaneoTheme.leaf : AnaneoTheme.hairline, lineWidth: isTitleFocused ? 2 : 1)
                    }
                TextField("Description, size, any flaws", text: $draft.details, axis: .vertical)
                    .lineLimit(2...6)
                    .padding(AnaneoTheme.Spacing.lg)
                    .background(AnaneoTheme.surface, in: RoundedRectangle(cornerRadius: AnaneoTheme.Radius.tile, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AnaneoTheme.Radius.tile, style: .continuous)
                            .strokeBorder(AnaneoTheme.hairline, lineWidth: 1)
                    }
            }

            VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.sm + 2) {
                Text("Category").sectionLabel()
                CategoryGrid(selection: $draft.category)
            }

            VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.sm + 2) {
                Text("Condition").sectionLabel()
                ConditionRow(selection: $draft.condition)
            }

            VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.sm + 2) {
                Text("Offer").sectionLabel()
                ModeCards(selection: $draft.mode)
                if draft.mode == .swap {
                    TextField("What would you like in return?", text: $draft.wants)
                        .padding(.horizontal, AnaneoTheme.Spacing.lg)
                        .frame(minHeight: AnaneoTheme.Size.pillButton)
                        .background(AnaneoTheme.sun.opacity(0.16), in: RoundedRectangle(cornerRadius: AnaneoTheme.Radius.tile, style: .continuous))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(AnaneoMotion.settle(reduceMotion: reduceMotion), value: draft.mode)

            Button("What can't be listed", systemImage: "nosign") { showingProhibited = true }
                .buttonStyle(.pill(.secondary, expanded: false))
        }
        .onAppear { isTitleFocused = draft.title.isEmpty }
    }

    private var postStep: some View {
        VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.xl) {
            VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.sm + 2) {
                Text("Ready to post").sectionLabel()
                HStack(spacing: AnaneoTheme.Spacing.md) {
                    if let cover = photos.first {
                        PhotoThumbnail(data: cover.data, isCover: false)
                    }
                    VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.xs + 2) {
                        Text(draft.trimmedTitle)
                            .font(.headline)
                            .foregroundStyle(AnaneoTheme.ink)
                            .lineLimit(2)
                        HStack(spacing: AnaneoTheme.Spacing.sm) {
                            ModeChip(mode: draft.mode)
                            Chip(title: draft.condition.title)
                        }
                        Text(draft.category.title)
                            .font(.footnote)
                            .foregroundStyle(AnaneoTheme.smoke)
                    }
                    Spacer(minLength: 0)
                }
                .card(padding: AnaneoTheme.Spacing.md)
            }

            VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.sm + 2) {
                Text("Pickup area").sectionLabel()
                pickupCard
                Text("Your exact address is never shown. Share it in a message only when you're ready.")
                    .font(.footnote)
                    .foregroundStyle(AnaneoTheme.smoke)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
        .onAppear { location.request() }
    }

    @ViewBuilder
    private var pickupCard: some View {
        switch location.status {
        case .ready:
            Label("Shown as an approximate area, within about ¼ mile of where you are now.", systemImage: "mappin.and.ellipse")
                .font(.subheadline)
                .foregroundStyle(AnaneoTheme.ink)
                .card(padding: AnaneoTheme.Spacing.md)
        case .locating:
            HStack(spacing: AnaneoTheme.Spacing.md) {
                LoopRing(progress: nil, lineWidth: 3).frame(width: 22)
                Text("Finding your area…").foregroundStyle(AnaneoTheme.smoke)
            }
            .card(padding: AnaneoTheme.Spacing.md)
        case .needsPermission:
            Button("Use My Location", systemImage: "location") { location.request() }
                .buttonStyle(.pill(.secondary))
        case .denied:
            Button("Allow Location in Settings", systemImage: "gear") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.pill(.secondary))
        }
    }

    // MARK: - Actions

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        isLoadingPhotos = true
        // A newer selection may still be loading. It clears the flag when it finishes.
        defer { if items == pickerItems { isLoadingPhotos = false } }
        // Photos still selected are already resized, so only new picks are loaded.
        let alreadyLoaded = photos
        var loaded: [PickedPhoto] = []
        for item in items {
            if let photo = alreadyLoaded.first(where: { $0.item == item }) {
                loaded.append(photo)
                continue
            }
            guard let raw = try? await item.loadTransferable(type: Data.self) else { continue }
            let prepared = await Task.detached(priority: .userInitiated) {
                ListingService.preparePhoto(raw)
            }.value
            if let prepared { loaded.append(PickedPhoto(item: item, data: prepared)) }
        }
        // Ignore stale results if the selection changed while loading.
        if items == pickerItems { photos = loaded }
    }

    /// Removes the photo and its picker selection together, so the two can't fall out of step.
    private func remove(_ photo: PickedPhoto) {
        photos.removeAll { $0.id == photo.id }
        pickerItems.removeAll { $0 == photo.item }
    }

    private func post() async {
        guard let coordinate else { return }
        errorMessage = nil
        isPosting = true
        defer { isPosting = false }
        do {
            try await listings.create(draft, photos: photos.map(\.data), at: coordinate)
            draft = ListingDraft()
            pickerItems = []
            photos = []
            onPosted()
        } catch {
            errorMessage = "Couldn't post: \(error.localizedDescription)"
        }
    }
}

/// A picked photo, resized and ready to upload, with the picker selection it came from.
private struct PickedPhoto: Identifiable {
    let id = UUID()
    let item: PhotosPickerItem
    let data: Data
}

/// One chosen photo, 84 points square, with a Cover tag on the first and a remove button when removable.
private struct PhotoThumbnail: View {
    let data: Data
    let isCover: Bool
    var onRemove: (() -> Void)? = nil

    var body: some View {
        Group {
            if let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                AnaneoTheme.track
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: AnaneoTheme.Radius.thumbnail, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            if isCover {
                Text("Cover")
                    .font(.system(.caption2, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AnaneoTheme.forest.opacity(0.75), in: Capsule())
                    .padding(6)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let onRemove {
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
}

#Preview {
    GiveFlow()
        .environment(ListingService())
        .environment(LocationService())
}
