import UIKit

@MainActor
final class ArtworkImageCache {
    static let shared = ArtworkImageCache()

    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func loadImage(from url: URL) async -> UIImage? {
        if let cached = image(for: url) {
            return cached
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            cache.setObject(image, forKey: url as NSURL)
            return image
        } catch {
            return nil
        }
    }
}
