import AVFoundation
import AVKit
import UIKit

@MainActor
enum MediaPlayerItemFactory {
    private static let artworkDataCache = NSCache<NSURL, NSData>()

    static func item(resource: MediaPlaybackResource, mediaItem: MediaItem) -> AVPlayerItem {
        let item = AVPlayerItem(url: resource.url)
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        item.externalMetadata = metadata(for: mediaItem, descriptionSuffix: resource.descriptionSuffix)
        return item
    }

    private static func metadata(for item: MediaItem, descriptionSuffix: String?) -> [AVMetadataItem] {
        [
            metadata(.commonIdentifierTitle, value: item.title),
            metadata(
                .commonIdentifierDescription,
                value: [item.synopsis, descriptionSuffix].compactMap { $0 }.joined(separator: "\n")
            ),
            artworkMetadata(for: item)
        ]
        .compactMap { $0 }
    }

    private static func metadata(_ identifier: AVMetadataIdentifier, value: String) -> AVMetadataItem {
        let metadata = AVMutableMetadataItem()
        metadata.identifier = identifier
        metadata.value = value as NSString
        metadata.extendedLanguageTag = "und"
        return metadata.copy() as! AVMetadataItem
    }

    private static func artworkMetadata(for item: MediaItem) -> AVMetadataItem? {
        guard let url = item.backdropURL ?? item.artworkURL else {
            return nil
        }

        let data: Data
        if let cached = artworkDataCache.object(forKey: url as NSURL) {
            data = cached as Data
        } else if let encoded = ArtworkImageCache.shared.image(for: url)?.jpegData(compressionQuality: 0.85) {
            data = encoded
            artworkDataCache.setObject(encoded as NSData, forKey: url as NSURL)
        } else {
            return nil
        }

        let metadata = AVMutableMetadataItem()
        metadata.identifier = .commonIdentifierArtwork
        metadata.value = data as NSData
        metadata.dataType = kCMMetadataBaseDataType_JPEG as String
        return metadata.copy() as? AVMetadataItem
    }
}
