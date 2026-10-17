import SwiftUI
import UIKit

/// Decoded images by URL, so a grid of thumbnails is not refetched or re-decoded on every scroll.
/// Requests for the same URL share one download.
@MainActor
final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    init() {
        cache.totalCostLimit = 120 * 1024 * 1024
    }

    /// The image if it is already decoded, for showing without a load.
    func cached(_ url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    /// Fetches and decodes the image, or returns `nil` when the URL is missing or not an image.
    func image(for url: URL) async -> UIImage? {
        if let image = cached(url) { return image }
        if let task = inFlight[url] { return await task.value }

        let task = Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let result = try? await URLSession.shared.data(from: url) else { return nil }
            if let http = result.1 as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
            guard let image = UIImage(data: result.0) else { return nil }
            // Decode off the main thread, so the first draw does not stutter.
            return image.preparingForDisplay() ?? image
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil
        if let image {
            let pixels = image.size.width * image.size.height * image.scale * image.scale
            cache.setObject(image, forKey: url as NSURL, cost: Int(pixels * 4))
        }
        return image
    }
}

/// A remote image from the cache, with a placeholder until it loads.
///
/// Tries each URL in order, so a grid can ask for the thumbnail first and fall back to the full photo
/// for listings posted before thumbnails existed. The image fills its frame; callers clip.
struct CachedImage<Placeholder: View>: View {
    let urls: [URL]
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
            }
        }
        .animation(.smooth(duration: 0.2), value: image == nil)
        .task(id: urls) { await load() }
    }

    private func load() async {
        if let url = urls.first, let cached = ImageCache.shared.cached(url) {
            image = cached
            return
        }
        for url in urls {
            if Task.isCancelled { return }
            if let loaded = await ImageCache.shared.image(for: url) {
                image = loaded
                return
            }
        }
    }
}

/// A listing photo with the category icon while it loads or when there is none.
struct ListingPhoto: View {
    let urls: [URL]
    let placeholder: String

    init(urls: [URL], placeholder: String) {
        self.urls = urls
        self.placeholder = placeholder
    }

    init(url: URL?, placeholder: String) {
        self.init(urls: url.map { [$0] } ?? [], placeholder: placeholder)
    }

    var body: some View {
        CachedImage(urls: urls) {
            ZStack {
                AnaneoTheme.track
                Image(systemName: placeholder)
                    .font(.title2)
                    .foregroundStyle(AnaneoTheme.smoke)
            }
        }
        .clipped()
    }
}

#Preview("Listing photo") {
    HStack(spacing: AnaneoTheme.Spacing.md) {
        ListingPhoto(url: nil, placeholder: "sofa")
            .frame(width: 96, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: AnaneoTheme.Radius.card, style: .continuous))
        ListingPhoto(urls: [URL(string: "https://picsum.photos/seed/ananeo/600/750")!], placeholder: "sofa")
            .frame(width: 96, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: AnaneoTheme.Radius.card, style: .continuous))
    }
    .padding()
}
