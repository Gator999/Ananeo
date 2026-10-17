import SwiftUI

/// Full-bleed photos for the listing hero, with a scrim so text reads over them and dots for paging.
/// Callers put the title and chips in an overlay at the bottom.
struct PhotoPager: View {
    let urls: [URL]
    let placeholder: String

    @State private var page = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            if urls.isEmpty {
                ListingPhoto(url: nil, placeholder: placeholder)
            } else {
                TabView(selection: $page) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                        ListingPhoto(url: url, placeholder: placeholder)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }

            scrim

            if urls.count > 1 {
                HStack(spacing: 5) {
                    ForEach(urls.indices, id: \.self) { index in
                        Circle()
                            .fill(.white.opacity(index == page ? 1 : 0.45))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.bottom, AnaneoTheme.Spacing.sm)
            }
        }
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(urls.count > 1 ? "Photo \(page + 1) of \(urls.count)" : "Photo")
    }

    /// Forest at the top for the toolbar, clear through the middle, Forest at the bottom for the title.
    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: AnaneoTheme.forest.opacity(0.35), location: 0),
                .init(color: .clear, location: 0.28),
                .init(color: .clear, location: 0.5),
                .init(color: AnaneoTheme.forest.opacity(0.86), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }
}

#Preview("Photo pager") {
    PhotoPager(
        urls: [
            URL(string: "https://picsum.photos/seed/one/900/1100")!,
            URL(string: "https://picsum.photos/seed/two/900/1100")!,
        ],
        placeholder: "sofa"
    )
    .frame(height: 430)
    .overlay(alignment: .bottomLeading) {
        VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.sm) {
            ModeChip(mode: .give)
            Text("Oak bookshelf").displayTitle().foregroundStyle(.white)
        }
        .padding(AnaneoTheme.Spacing.xl)
        .padding(.bottom, AnaneoTheme.Spacing.sm)
    }
    .ignoresSafeArea()
}
