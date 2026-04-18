import SwiftUI

struct LibraryItemCard: View {
    let item: MediaItem
    let artworkStyle: MediaArtworkStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            artwork

            Text(item.title)
                .font(.headline)
                .lineLimit(2)

            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var artwork: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.surfaceFill)
                .overlay {
                    AsyncImage(url: item.artwork.url(for: artworkStyle)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Image(systemName: artworkStyle == .poster ? "film.stack.fill" : "tv.fill")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                }
                .clipped()

            if let progress = item.progress, !item.isWatched {
                GeometryReader { proxy in
                    Capsule()
                        .fill(AppTheme.emphasizedSurfaceFill)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(MediaWatchStatusDisplay.color)
                                .frame(width: proxy.size.width * min(max(progress, 0), 1))
                        }
                        .frame(height: 6)
                        .padding(10)
                }
            }
        }
        .aspectRatio(artworkStyle.aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
