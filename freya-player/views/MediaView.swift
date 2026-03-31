import SwiftUI

struct MediaViewData {
    let title: String
    let metadata: [Metadata]
    let synopsis: String
    let artworkURL: URL?
    let artworkStyle: MediaArtworkStyle
    let backdropURL: URL?
    let playbackID: MediaPlaybackID?
    let hasResume: Bool
    let resumeOffsetMilliseconds: Int?

    struct Metadata: Identifiable {
        let label: String
        let value: String

        var id: String { label }
    }
}

enum MediaArtworkStyle {
    case poster
    case landscape

    var aspectRatio: CGFloat {
        switch self {
        case .poster:
            return 2 / 3
        case .landscape:
            return 16 / 9
        }
    }

    var width: CGFloat {
        switch self {
        case .poster:
            return 480
        case .landscape:
            return 780
        }
    }

    var imageRequestWidth: Int {
        Int(width * 2)
    }

    var imageRequestHeight: Int {
        Int(CGFloat(imageRequestWidth) / aspectRatio)
    }

    func fittedSize(in bounds: CGSize) -> CGSize {
        let width = min(width, bounds.width)
        let height = width / aspectRatio

        if height <= bounds.height {
            return CGSize(width: width, height: height)
        }

        let fittedHeight = bounds.height
        return CGSize(width: fittedHeight * aspectRatio, height: fittedHeight)
    }
}

struct MediaView<Content: View>: View {
    @ObservedObject var model: AppModel
    let data: MediaViewData
    let content: Content
    private let horizontalPadding: CGFloat = 72
    private let artworkSpacing: CGFloat = 72

    init(
        model: AppModel,
        data: MediaViewData,
        @ViewBuilder content: () -> Content
    ) {
        self.model = model
        self.data = data
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let panelWidth = (proxy.size.width - (horizontalPadding * 2) - artworkSpacing) / 2
            let synopsisWidth = min(panelWidth - 72, 980)
            let artworkBounds = CGSize(width: panelWidth, height: proxy.size.height - 96)
            let artworkSize = data.artworkStyle.fittedSize(in: artworkBounds)

            HStack(spacing: 72) {
                ScrollView {
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
                            MediaPlayButton(
                                model: model,
                                id: playbackID,
                                hasResume: data.hasResume,
                                resumeOffsetMilliseconds: data.resumeOffsetMilliseconds
                            )
                        }

                        content

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 36)
                    .padding(.vertical, 24)
                    .frame(minHeight: proxy.size.height - 96, alignment: .center)
                }
                .frame(width: panelWidth, alignment: .leading)
                .scrollIndicators(.hidden)
                .scrollClipDisabled()

                VStack {
                    Spacer(minLength: 0)

                    MediaArtworkView(url: data.artworkURL, title: data.title, style: data.artworkStyle)
                        .frame(width: artworkSize.width, height: artworkSize.height)

                    Spacer(minLength: 0)
                }
                .frame(width: panelWidth)
                .clipped()
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 48)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background {
            MediaBackdropView(url: data.backdropURL)
        }
    }
}

extension MediaView where Content == EmptyView {
    init(model: AppModel, data: MediaViewData) {
        self.init(model: model, data: data) {
            EmptyView()
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

private struct MediaArtworkView: View {
    let url: URL?
    let title: String
    let style: MediaArtworkStyle
    private let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)

    var body: some View {
        ZStack {
            shape
                .fill(Color.white.opacity(0.08))

            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Image(systemName: "film.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(1)
        }
        .aspectRatio(style.aspectRatio, contentMode: .fit)
        .clipShape(shape)
        .shadow(color: .black.opacity(0.35), radius: 28, y: 18)
        .accessibilityLabel(title)
    }
}
