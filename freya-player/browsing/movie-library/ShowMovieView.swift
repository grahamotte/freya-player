import SwiftUI

struct ShowMovieView: View {
    @ObservedObject var model: AppModel
    let item: PlexMediaItem

    var body: some View {
        Group {
            if let summary = model.connectedSummary {
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        PlexMovieArtworkView(
                            url: item.artworkURL(
                                baseURL: summary.serverURL,
                                token: summary.serverToken,
                                width: 720,
                                height: 1080
                            ),
                            title: item.title
                        )

                        VStack(alignment: .leading, spacing: 18) {
                            Text(item.title)
                                .font(.largeTitle.weight(.semibold))

                            MediaPlayButton(model: model, id: .plex(item.ratingKey))
                        }
                    }
                    .padding(48)
                }
                .background(AppBackground())
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppBackground())
            }
        }
        .navigationTitle(item.title)
    }
}

private struct PlexMovieArtworkView: View {
    let url: URL?
    let title: String

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(2 / 3, contentMode: .fit)
            default:
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .overlay {
                        Image(systemName: "film.fill")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(maxWidth: 420)
        .accessibilityLabel(title)
    }
}
