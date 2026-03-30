import SwiftUI

struct MediaViewData {
    let title: String
    let metadata: [Metadata]
    let synopsis: String
    let posterURL: URL?
    let backdropURL: URL?
    let playbackID: MediaPlaybackID?

    struct Metadata: Identifiable {
        let label: String
        let value: String

        var id: String { label }
    }
}

struct MediaView: View {
    @ObservedObject var model: AppModel
    let data: MediaViewData

    var body: some View {
        GeometryReader { proxy in
            let posterWidth = min(proxy.size.width * 0.28, 420)
            let synopsisWidth = min(proxy.size.width * 0.62, 980)

            HStack(spacing: 72) {
                VStack(alignment: .leading, spacing: 32) {
                    Spacer(minLength: 0)

                    Text(data.title)
                        .font(.system(size: 58, weight: .bold))
                        .lineLimit(3)

                    if !data.metadata.isEmpty {
                        HStack(alignment: .top, spacing: 44) {
                            ForEach(data.metadata) { entry in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(entry.label)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.secondary)

                                    Text(entry.value)
                                        .font(.headline.weight(.medium))
                                }
                            }
                        }
                    }

                    Text(data.synopsis)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                        .frame(maxWidth: synopsisWidth, maxHeight: 220, alignment: .topLeading)

                    if let playbackID = data.playbackID {
                        MediaPlayButton(model: model, id: playbackID)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                MediaPosterView(url: data.posterURL, title: data.title)
                    .frame(width: posterWidth)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 72)
            .padding(.vertical, 48)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background {
            MediaBackdropView(url: data.backdropURL)
        }
    }
}

private struct MediaBackdropView: View {
    let url: URL?

    var body: some View {
        ZStack {
            AppBackground()

            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 56)
                        .opacity(0.32)
                }
            }
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.2),
                    Color.black.opacity(0.62)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.05),
                    Color.black.opacity(0.1),
                    Color.black.opacity(0.72)
                ],
                startPoint: .trailing,
                endPoint: .leading
            )
            .ignoresSafeArea()
        }
    }
}

private struct MediaPosterView: View {
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
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .overlay {
                        Image(systemName: "film.fill")
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 28, y: 18)
        .accessibilityLabel(title)
    }
}
