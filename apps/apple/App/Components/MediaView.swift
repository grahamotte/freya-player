import SwiftUI

struct MediaViewData {
    let title: String
    let metadata: [Metadata]
    let detailSections: [MediaItemDetailSection]
    let detailArtwork: [Artwork]
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

    struct Artwork: Identifiable {
        let label: String
        let url: URL
        let style: MediaArtworkStyle

        var id: String { "\(label):\(url.absoluteString)" }
    }
}

struct MediaView<Content: View>: View {
    @ObservedObject var model: AppModel
    let data: MediaViewData
    let content: Content
    @State private var isShowingFullText = false
    @State private var isShowingDetails = false
    @State private var detailScrollOffset: CGFloat = 0

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

            if usesPortraitLayout(proxy) {
                portraitLayout(proxy: proxy, metrics: metrics)
            } else {
                splitLayout(proxy: proxy, metrics: metrics)
            }
        }
        .background {
            MediaBackdropView(artworkURL: data.artworkURL, backdropURL: data.backdropURL)
        }
        .fullScreenCover(isPresented: $isShowingFullText) {
            FullItemTextView(title: data.title, synopsis: data.synopsis)
                .presentationBackground(.clear)
        }
        .fullScreenCover(isPresented: $isShowingDetails) {
            FullItemDetailsView(
                title: data.title,
                synopsis: data.synopsis,
                sections: data.detailSections,
                artwork: data.detailArtwork,
                artworkURL: data.artworkURL,
                backdropURL: data.backdropURL
            )
                .presentationBackground(.clear)
        }
    }

    private func usesPortraitLayout(_ proxy: GeometryProxy) -> Bool {
        !PlatformMetadata.isTV && proxy.size.height > proxy.size.width
    }

    private func portraitLayout(proxy: GeometryProxy, metrics: MediaViewMetrics) -> some View {
        let metrics = metrics.balancedPanelPadding
        let availableWidth = proxy.size.width - (metrics.horizontalPadding * 2)
        let synopsisWidth = availableWidth - metrics.panelHorizontalPadding
        let fade = min(max(detailScrollOffset / 160, 0), 1)
        let fadeOpacity = Double(fade)
        let artworkSectionHeight = proxy.size.height * 0.38
        let artworkBounds = CGSize(
            width: availableWidth,
            height: max(artworkSectionHeight - metrics.topPadding, 1)
        )
        let artworkSize = data.artworkStyle.fittedSize(in: artworkBounds)

        return VStack(spacing: 0) {
            VStack {
                Spacer(minLength: metrics.topPadding)

                MediaArtworkView(url: data.artworkURL, title: data.title, style: data.artworkStyle)
                    .frame(width: artworkSize.width, height: artworkSize.height)
                    .overlay {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .black.opacity(fadeOpacity * 0.12),
                                        .black.opacity(fadeOpacity * 0.96)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .opacity(1 - fadeOpacity)

                Spacer(minLength: 0)
            }
            .frame(height: artworkSectionHeight)

            detailsPanel(
                width: availableWidth,
                synopsisWidth: synopsisWidth,
                metrics: metrics,
                tracksOffset: true
            )
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.bottom, metrics.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func splitLayout(proxy: GeometryProxy, metrics: MediaViewMetrics) -> some View {
        let availableWidth = proxy.size.width - (metrics.horizontalPadding * 2) - metrics.artworkSpacing
        let detailWidth = availableWidth * 0.62
        let artworkWidth = availableWidth * 0.38
        let synopsisWidth = min(detailWidth - metrics.panelHorizontalPadding, 980)
        let artworkBounds = CGSize(width: artworkWidth, height: proxy.size.height - (metrics.verticalPadding * 2))
        let artworkSize = data.artworkStyle.fittedSize(in: artworkBounds)

        return HStack(spacing: metrics.artworkSpacing) {
            detailsPanel(
                width: detailWidth,
                synopsisWidth: synopsisWidth,
                metrics: metrics,
                tracksOffset: false
            )

            VStack {
                MediaArtworkView(url: data.artworkURL, title: data.title, style: data.artworkStyle)
                    .frame(width: artworkSize.width, height: artworkSize.height)
            }
            .frame(width: artworkWidth)
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, metrics.topPadding)
        .padding(.bottom, metrics.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func detailsPanel(
        width: CGFloat,
        synopsisWidth: CGFloat,
        metrics: MediaViewMetrics,
        tracksOffset: Bool
    ) -> some View {
        ScrollView {
            detailsContent(synopsisWidth: synopsisWidth, metrics: metrics)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            guard tracksOffset else { return 0 }
            return max(geometry.contentOffset.y + geometry.contentInsets.top, 0)
        } action: { _, offset in
            detailScrollOffset = offset
        }
        .padding(.leading, metrics.panelLeadingPadding)
        .padding(.trailing, metrics.panelTrailingPadding)
        .padding(.vertical, metrics.panelVerticalPadding)
        .frame(width: width, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .leading)
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollClipDisabled()
    }

    @ViewBuilder
    private func detailsContent(synopsisWidth: CGFloat, metrics: MediaViewMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.contentSpacing) {
            Button {
                isShowingFullText = true
            } label: {
                Text(data.title)
                    .font(.system(size: metrics.titleFontSize, weight: .bold))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(MediaDetailTextButtonStyle())

            if !data.metadata.isEmpty || !data.detailSections.isEmpty {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: metrics.horizontalItemSpacing) {
                        ForEach(data.metadata) { entry in
                            Button {} label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(entry.label)
                                        .font(metrics.metadataLabelFont)
                                        .foregroundStyle(AppTheme.secondaryText)

                                    Text(entry.value)
                                        .font(metrics.metadataValueFont)
                                }
                                .frame(minWidth: metrics.metadataTileWidth, alignment: .leading)
                            }
                            .buttonStyle(MediaDetailTileStyle())
                        }

                        Button { isShowingDetails = true } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("More")
                                    .font(metrics.metadataLabelFont)
                                    .foregroundStyle(AppTheme.secondaryText)

                                Text("Details")
                                    .font(metrics.metadataValueFont)
                            }
                            .frame(minWidth: metrics.metadataTileWidth, alignment: .leading)
                        }
                        .buttonStyle(MediaDetailTileStyle())
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: synopsisWidth, alignment: .leading)
                .horizontalFade()
            }

            Button {
                isShowingFullText = true
            } label: {
                Text(data.synopsis)
                    .font(.body)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(5)
                    .frame(maxWidth: synopsisWidth, alignment: .topLeading)
            }
            .buttonStyle(MediaDetailTextButtonStyle())

            content
        }
        .frame(maxWidth: synopsisWidth, alignment: .leading)
    }
}

struct MediaItemActionRow<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                content
            }
        }
        .scrollIndicators(.hidden)
        .horizontalFade()
    }
}

extension MediaView where Content == EmptyView {
    init(model: AppModel, data: MediaViewData) {
        self.init(model: model, data: data) {
            EmptyView()
        }
    }
}

private struct FullScreenLayout {
    let size: CGSize

    var horizontalPadding: CGFloat {
        if PlatformMetadata.isTV {
            return min(72, max(32, size.width * 0.04))
        }

        return size.width < 600 ? 16 : 32
    }

    var controlTopPadding: CGFloat {
        PlatformMetadata.isTV ? 32 : 16
    }

    var contentBottomPadding: CGFloat {
        PlatformMetadata.isTV ? 64 : 32
    }

    func contentWidth(maximum: CGFloat) -> CGFloat {
        min(maximum, max(size.width - (horizontalPadding * 2), 1))
    }
}

private struct FullItemDetailsView: View {
    let title: String
    let synopsis: String
    let sections: [MediaItemDetailSection]
    let artwork: [MediaViewData.Artwork]
    let artworkURL: URL?
    let backdropURL: URL?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedItemID: String?

    var body: some View {
        GeometryReader { proxy in
            let layout = FullScreenLayout(size: proxy.size)
            let contentWidth = layout.contentWidth(maximum: PlatformMetadata.isTV ? 1600 : 1040)

            ZStack {
                MediaBackdropView(artworkURL: artworkURL, backdropURL: backdropURL)

                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: contentSpacing) {
                        closeButton
                        header
                        descriptionSection

                        if !artwork.isEmpty {
                            artworkGallery(availableWidth: contentWidth)
                        }

                        LazyVStack(alignment: .leading, spacing: sectionSpacing) {
                            ForEach(sections) { section in
                                if !section.rows.isEmpty {
                                    detailSection(section, availableWidth: contentWidth)
                                }
                            }
                        }
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.top, layout.controlTopPadding)
                    .padding(.bottom, layout.contentBottomPadding)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .tvOSFocusSection()
                }
                .scrollIndicators(.hidden)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .tvExitCommand { dismiss() }
        .defaultFocus($focusedItemID, initialFocusID)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(PlatformMetadata.isTV ? .system(size: 58, weight: .bold) : .largeTitle.bold())
                .frame(maxWidth: 1100, alignment: .leading)

            Text("\(rowCount) fields across \(nonemptySections.count) sections")
                .font(.callout)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var descriptionSection: some View {
        let focusID = "description"
        let isFocused = focusedItemID == focusID

        return VStack(alignment: .leading, spacing: 16) {
            detailHeading("Description", caption: nil)

            Text(synopsis)
                .font(.body)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .userSelectableText()
                .padding(PlatformMetadata.isTV ? 20 : 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isFocused ? AppTheme.emphasizedSurfaceFill : AppTheme.subtleSurfaceFill)
                }
                .focusable(PlatformMetadata.isTV)
                .focused($focusedItemID, equals: focusID)
        }
        .tvOSFocusSection()
    }

    private func artworkGallery(availableWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            detailHeading("Artwork", caption: nil)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: PlatformMetadata.isTV ? 24 : 16) {
                    ForEach(artwork) { image in
                        let focusID = "artwork:\(image.id)"

                        FullItemDetailArtwork(
                            image: image,
                            isFocused: focusedItemID == focusID,
                            availableWidth: availableWidth
                        )
                            .focusable(PlatformMetadata.isTV)
                            .focused($focusedItemID, equals: focusID)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
            .scrollIndicators(.hidden)
        }
        .tvOSFocusSection()
    }

    private func detailSection(_ section: MediaItemDetailSection, availableWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: PlatformMetadata.isTV ? 24 : 18) {
            detailHeading(
                section.title,
                caption: "\(section.rows.count) \(section.rows.count == 1 ? "field" : "fields")"
            )

            LazyVGrid(
                columns: detailColumns(availableWidth: availableWidth),
                alignment: .leading,
                spacing: gridSpacing
            ) {
                ForEach(section.rows) { row in
                    let focusID = rowFocusID(section: section, row: row)

                    FullItemDetailRow(row: row, isFocused: focusedItemID == focusID)
                        .focusable(PlatformMetadata.isTV)
                        .focused($focusedItemID, equals: focusID)
                }
            }
        }
        .padding(.vertical, PlatformMetadata.isTV ? 20 : 12)
        .overlay(alignment: .top) {
            Divider()
                .overlay(AppTheme.surfaceBorder)
        }
        .tvOSFocusSection()
    }

    private func detailHeading(_ title: String, caption: String?) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(title)
                    .font(PlatformMetadata.isTV ? .title2.bold() : .title3.bold())

                Spacer(minLength: 0)

                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(PlatformMetadata.isTV ? .title2.bold() : .title3.bold())

                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
    }

    private func detailColumns(availableWidth: CGFloat) -> [GridItem] {
        let preferredMinimum: CGFloat = PlatformMetadata.isTV ? 360 : (PlatformMetadata.isPhone ? 220 : 280)
        let minimum = min(preferredMinimum, max(availableWidth, 1))
        return [GridItem(.adaptive(minimum: minimum), spacing: gridSpacing, alignment: .top)]
    }

    private var contentSpacing: CGFloat {
        PlatformMetadata.isTV ? 48 : 32
    }

    private var sectionSpacing: CGFloat {
        PlatformMetadata.isTV ? 28 : 20
    }

    private var gridSpacing: CGFloat {
        PlatformMetadata.isTV ? 16 : 12
    }

    private var nonemptySections: [MediaItemDetailSection] {
        sections.filter { !$0.rows.isEmpty }
    }

    private var rowCount: Int {
        sections.reduce(0) { $0 + $1.rows.count }
    }

    private var initialFocusID: String? {
        guard PlatformMetadata.isTV else { return nil }
        return "description"
    }

    private func rowFocusID(section: MediaItemDetailSection, row: MediaItemDetailSection.Row) -> String {
        return "\(section.id):\(row.id)"
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Label("Close", systemImage: "xmark")
        }
        .buttonStyle(
            MediaGlassButtonStyle(
                horizontalPadding: PlatformMetadata.isTV ? 22 : 20,
                verticalPadding: PlatformMetadata.isTV ? 14 : 10
            )
        )
    }
}

private struct FullItemDetailArtwork: View {
    let image: MediaViewData.Artwork
    let isFocused: Bool
    let availableWidth: CGFloat

    private var height: CGFloat {
        let preferredHeight: CGFloat = PlatformMetadata.isTV ? 280 : 210
        let availableImageWidth = max(availableWidth - 20, 1)
        return min(preferredHeight, availableImageWidth / image.style.aspectRatio)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MediaArtworkView(url: image.url, title: image.label, style: image.style)
                .frame(width: height * image.style.aspectRatio, height: height)

            Text(image.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(isFocused ? AppTheme.emphasizedSurfaceFill : .clear)
        }
    }
}

private struct FullItemDetailRow: View {
    let row: MediaItemDetailSection.Row
    let isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(row.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)

            Text(row.value)
                .font(.body.monospaced())
                .foregroundStyle(AppTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .userSelectableText()
        }
        .frame(maxWidth: .infinity, minHeight: PlatformMetadata.isTV ? 86 : 72, alignment: .topLeading)
        .padding(PlatformMetadata.isTV ? 20 : 16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isFocused ? AppTheme.emphasizedSurfaceFill : AppTheme.subtleSurfaceFill)
        }
    }
}

private struct MediaViewMetrics {
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let artworkSpacing: CGFloat
    let panelLeadingPadding: CGFloat
    let panelTrailingPadding: CGFloat
    let panelVerticalPadding: CGFloat
    let contentSpacing: CGFloat
    let horizontalItemSpacing: CGFloat
    let metadataTileWidth: CGFloat
    let metadataLabelFont: Font
    let metadataValueFont: Font
    let titleFontSize: CGFloat
    let headerOffset: CGFloat

    var panelHorizontalPadding: CGFloat {
        panelLeadingPadding + panelTrailingPadding
    }

    var topPadding: CGFloat {
        verticalPadding - headerOffset
    }

    var bottomPadding: CGFloat {
        verticalPadding + headerOffset
    }

    var balancedPanelPadding: MediaViewMetrics {
        MediaViewMetrics(
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            artworkSpacing: artworkSpacing,
            panelLeadingPadding: 0,
            panelTrailingPadding: 0,
            panelVerticalPadding: panelVerticalPadding,
            contentSpacing: contentSpacing,
            horizontalItemSpacing: horizontalItemSpacing,
            metadataTileWidth: metadataTileWidth,
            metadataLabelFont: metadataLabelFont,
            metadataValueFont: metadataValueFont,
            titleFontSize: titleFontSize,
            headerOffset: headerOffset
        )
    }

    static let current: MediaViewMetrics = {
        if PlatformMetadata.isTV {
            return MediaViewMetrics(
                horizontalPadding: 72,
                verticalPadding: 48,
                artworkSpacing: 72,
                panelLeadingPadding: 36,
                panelTrailingPadding: 36,
                panelVerticalPadding: 24,
                contentSpacing: 32,
                horizontalItemSpacing: 12,
                metadataTileWidth: 128,
                metadataLabelFont: .caption.weight(.semibold),
                metadataValueFont: .callout.weight(.medium),
                titleFontSize: 58,
                headerOffset: 0
            )
        }
        if PlatformMetadata.isMac {
            return MediaViewMetrics(
                horizontalPadding: 32,
                verticalPadding: 32,
                artworkSpacing: 32,
                panelLeadingPadding: 0,
                panelTrailingPadding: 40,
                panelVerticalPadding: 16,
                contentSpacing: 24,
                horizontalItemSpacing: 12,
                metadataTileWidth: 112,
                metadataLabelFont: .footnote.weight(.semibold),
                metadataValueFont: .headline.weight(.medium),
                titleFontSize: 38,
                headerOffset: 18
            )
        }
        if PlatformMetadata.isPhone {
            return MediaViewMetrics(
                horizontalPadding: 20,
                verticalPadding: 20,
                artworkSpacing: 20,
                panelLeadingPadding: 0,
                panelTrailingPadding: 0,
                panelVerticalPadding: 12,
                contentSpacing: 16,
                horizontalItemSpacing: 12,
                metadataTileWidth: 96,
                metadataLabelFont: .footnote.weight(.semibold),
                metadataValueFont: .headline.weight(.medium),
                titleFontSize: 28,
                headerOffset: 0
            )
        }
        return MediaViewMetrics(
            horizontalPadding: 32,
            verticalPadding: 32,
            artworkSpacing: 32,
            panelLeadingPadding: 0,
            panelTrailingPadding: 40,
            panelVerticalPadding: 16,
            contentSpacing: 24,
            horizontalItemSpacing: 12,
            metadataTileWidth: 112,
            metadataLabelFont: .footnote.weight(.semibold),
            metadataValueFont: .headline.weight(.medium),
            titleFontSize: 38,
            headerOffset: 0
        )
    }()
}

private extension View {
    func horizontalFade() -> some View {
        mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.9),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}

private struct MediaDetailTextButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isFocused ? AppTheme.primaryText.opacity(0.16) : .clear)
            }
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

private struct MediaDetailTileStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isFocused ? AppTheme.primaryText.opacity(0.16) : AppTheme.surfaceFill.opacity(0.55))
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct FullItemTextView: View {
    let title: String
    let synopsis: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { proxy in
            let layout = FullScreenLayout(size: proxy.size)

            ZStack {
                Color.black.opacity(0.88)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        closeButton

                        Text(title)
                            .font(.largeTitle.bold())

                        Text(synopsis)
                            .font(.body)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .frame(width: layout.contentWidth(maximum: 860), alignment: .leading)
                    .padding(.top, layout.controlTopPadding)
                    .padding(.bottom, layout.contentBottomPadding)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .tvExitCommand { dismiss() }
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Label("Close", systemImage: "xmark")
        }
        .buttonStyle(
            MediaGlassButtonStyle(
                horizontalPadding: PlatformMetadata.isTV ? 22 : 20,
                verticalPadding: PlatformMetadata.isTV ? 14 : 10
            )
        )
    }
}

private extension View {
    func tvExitCommand(_ action: @escaping () -> Void) -> some View {
        #if os(tvOS)
        return onExitCommand(perform: action)
        #else
        return self
        #endif
    }
}

private struct MediaBackdropView: View {
    let artworkURL: URL?
    let backdropURL: URL?
    @State private var colors: [Color] = []

    private var paletteURL: URL? {
        artworkURL ?? backdropURL
    }

    var body: some View {
        ZStack {
            AppBackground()

            if !colors.isEmpty {
                AmbientMeshBackground(
                    colors: colors,
                    hueRotationRange: 0,
                    blurRadius: 132,
                    saturation: 0.9,
                    opacity: 0.66
                )
                .ignoresSafeArea()
            }

            AsyncImage(url: backdropURL) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 56)
                        .opacity(0.16)
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
        .task(id: paletteURL) {
            colors = []
            guard let paletteURL else { return }
            guard let image = await ArtworkImageCache.shared.loadImage(from: paletteURL) else { return }

            let palette = ArtworkPalette.colors(from: image)
            guard !palette.isEmpty else { return }
            colors = palette
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
            .fill(AppTheme.surfaceFill)
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
                            .foregroundStyle(AppTheme.secondaryText)
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
