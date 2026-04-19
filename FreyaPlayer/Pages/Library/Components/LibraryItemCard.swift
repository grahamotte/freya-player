import SwiftUI

struct LibraryItemCard: View {
    let item: MediaItem
    let artworkStyle: MediaArtworkStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            artwork

            Text(item.title)
                .font(.headline)
                .lineLimit(1)

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
                .overlay {
                    ArtworkProgressIndicator(progress: item.progress, isWatched: item.isWatched)
                }
        }
        .aspectRatio(artworkStyle.aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
