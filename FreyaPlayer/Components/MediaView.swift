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

struct MediaView<Content: View>: View {
    @ObservedObject var model: AppModel
    let data: MediaViewData
    let content: Content
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
            let metrics = MediaViewMetrics.current
            let panelWidth = (proxy.size.width - (metrics.horizontalPadding * 2) - metrics.artworkSpacing) / 2
            let synopsisWidth = min(panelWidth - metrics.panelInnerPadding, 980)
            let artworkBounds = CGSize(width: panelWidth, height: proxy.size.height - (metrics.verticalPadding * 2))
            let artworkSize = data.artworkStyle.fittedSize(in: artworkBounds)

            HStack(spacing: metrics.artworkSpacing) {
                detailsPanel(
                    width: panelWidth,
                    minHeight: proxy.size.height - (metrics.verticalPadding * 2),
                    synopsisWidth: synopsisWidth,
                    metrics: metrics
                )

                VStack(alignment: .trailing) {
                    Spacer(minLength: 0)

                    MediaArtworkView(url: data.artworkURL, title: data.title, style: data.artworkStyle)
                        .frame(width: artworkSize.width, height: artworkSize.height)

                    Spacer(minLength: 0)
                }
                .frame(width: panelWidth, alignment: .trailing)
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background {
            MediaBackdropView(url: data.backdropURL)
        }
    }

    private func detailsPanel(
        width: CGFloat,
        minHeight: CGFloat,
        synopsisWidth: CGFloat,
        metrics: MediaViewMetrics
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: metrics.contentSpacing) {
                Spacer(minLength: 0)

                Text(data.title)
                    .font(.system(size: metrics.titleFontSize, weight: .bold))
                    .lineLimit(3)

                if !data.metadata.isEmpty {
                    HStack(alignment: .top, spacing: metrics.metadataSpacing) {
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

                content

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, metrics.panelInnerPadding / 2)
        .padding(.vertical, metrics.panelVerticalPadding)
        .frame(width: width, alignment: .leading)
        .frame(minHeight: minHeight, alignment: .topLeading)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}

extension MediaView where Content == EmptyView {
    init(model: AppModel, data: MediaViewData) {
        self.init(model: model, data: data) {
            EmptyView()
        }
    }
}

private struct MediaViewMetrics {
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let artworkSpacing: CGFloat
    let panelInnerPadding: CGFloat
    let panelVerticalPadding: CGFloat
    let contentSpacing: CGFloat
    let metadataSpacing: CGFloat
    let titleFontSize: CGFloat

    static let current: MediaViewMetrics = {
        #if os(tvOS)
        MediaViewMetrics(
            horizontalPadding: 72,
            verticalPadding: 48,
            artworkSpacing: 72,
            panelInnerPadding: 72,
            panelVerticalPadding: 24,
            contentSpacing: 32,
            metadataSpacing: 44,
            titleFontSize: 58
        )
        #else
        MediaViewMetrics(
            horizontalPadding: 32,
            verticalPadding: 32,
            artworkSpacing: 32,
            panelInnerPadding: 40,
            panelVerticalPadding: 16,
            contentSpacing: 24,
            metadataSpacing: 28,
            titleFontSize: 38
        )
        #endif
    }()
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
        shape
            .fill(Color.white.opacity(0.08))
            .overlay {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
        .aspectRatio(style.aspectRatio, contentMode: .fit)
        .clipShape(shape)
        .shadow(color: .black.opacity(0.35), radius: 28, y: 18)
        .accessibilityLabel(title)
    }
}
