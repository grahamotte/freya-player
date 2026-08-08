import SwiftUI
import UIKit

struct LibraryItemCard: View {
    let item: MediaItem
    let artworkStyle: MediaArtworkStyle
    let showsAddedAt: Bool

    @State private var artworkImage: UIImage?
    @State private var isHovered = false

    private var artworkURL: URL? {
        item.artwork.url(for: artworkStyle)
    }

    init(item: MediaItem, artworkStyle: MediaArtworkStyle, showsAddedAt: Bool = false) {
        self.item = item
        self.artworkStyle = artworkStyle
        self.showsAddedAt = showsAddedAt
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            artwork

            VStack(alignment: .leading, spacing: PlatformMetadata.libraryTileTitleSubtitleSpacing) {
                MarqueeText(
                    text: item.title,
                    font: .headline,
                    isActive: PlatformMetadata.supportsItemTitleHoverMarquee && isHovered
                )

                if let subtitle = item.libraryTileSubtitle(showsAddedAt: showsAddedAt) {
                    Text(subtitle)
                        .font(PlatformMetadata.libraryTileSubtitleFont)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .platformHover { isHovered = $0 }
    }

    private var artwork: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.surfaceFill)
                .overlay {
                    if let artworkImage {
                        Image(uiImage: artworkImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: artworkStyle == .poster ? "film.stack.fill" : "tv.fill")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .clipped()
                .overlay(alignment: .bottomTrailing) {
                    WatchProgressCircle(progress: item.progress, isWatched: item.isWatched)
                        .padding(WatchProgressCircle.padding)
                }
        }
        .aspectRatio(artworkStyle.aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .task(id: artworkURL) {
            artworkImage = nil
            guard let artworkURL else { return }

            if let cachedImage = ArtworkImageCache.shared.image(for: artworkURL) {
                artworkImage = cachedImage
                return
            }

            let loadedImage = await ArtworkImageCache.shared.loadImage(from: artworkURL)
            guard !Task.isCancelled else { return }
            artworkImage = loadedImage
        }
    }
}
