import Foundation

extension MediaItem {
    func mediaViewData() -> MediaViewData {
        MediaViewData(
            title: title,
            metadata: [
                runtimeText.map { .init(label: "Length", value: $0) },
                releasedAtFormatted.map { .init(label: "Released", value: $0) },
                addedAtFormatted.map { .init(label: "Added", value: $0) }
            ]
            .compactMap { $0 },
            detailSections: [
                MediaItemDetailSection(
                    title: "General",
                    rows: [
                        .init(label: "Provider", value: providerID.title),
                        .init(label: "Server ID", value: serverID),
                        .init(label: "Type", value: kind.rawValue.capitalized),
                        year.map { .init(label: "Year", value: String($0)) },
                        contentRating.map { .init(label: "Content Rating", value: $0) },
                        runtimeText.map { .init(label: "Length", value: $0) },
                        durationMilliseconds.map { .init(label: "Duration", value: "\($0) ms") },
                        releasedAtFormatted.map { .init(label: "Released", value: $0) },
                        addedAtFormatted.map { .init(label: "Added", value: $0) },
                        .init(label: "Watched", value: isWatched ? "Yes" : "No"),
                        progress.map { .init(label: "Progress", value: $0.formatted(.percent.precision(.fractionLength(0)))) },
                        resumeOffsetMilliseconds.map { .init(label: "Resume Offset", value: "\($0) ms") },
                        .init(label: "Item ID", value: id),
                        tmdbID.map { .init(label: "TMDB ID", value: $0) }
                    ]
                    .compactMap { $0 }
                )
            ] + (detailSections ?? []),
            detailArtwork: [
                artwork.posterURL.map { .init(label: "Poster", url: $0, style: .poster) },
                artwork.thumbnailURL.map { .init(label: "Thumbnail", url: $0, style: kind.artworkStyle) },
                artwork.landscapeURL.map { .init(label: "Landscape", url: $0, style: .landscape) },
                artwork.backdropURL.map { .init(label: "Backdrop", url: $0, style: .landscape) }
            ]
            .compactMap { $0 },
            synopsis: synopsis,
            artworkURL: artwork.url(for: kind.artworkStyle),
            artworkStyle: kind.artworkStyle,
            backdropURL: backdropURL,
            playbackID: playbackID,
            hasResume: hasResume,
            resumeOffsetMilliseconds: !isWatched ? resumeOffsetMilliseconds : nil
        )
    }
}
