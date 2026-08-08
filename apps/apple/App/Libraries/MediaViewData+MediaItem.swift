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
                        .init(label: "Type", value: kind.rawValue.capitalized),
                        year.map { .init(label: "Year", value: String($0)) },
                        contentRating.map { .init(label: "Content Rating", value: $0) },
                        runtimeText.map { .init(label: "Length", value: $0) },
                        releasedAtFormatted.map { .init(label: "Released", value: $0) },
                        addedAtFormatted.map { .init(label: "Added", value: $0) },
                        .init(label: "Watched", value: isWatched ? "Yes" : "No"),
                        progress.map { .init(label: "Progress", value: $0.formatted(.percent.precision(.fractionLength(0)))) },
                        .init(label: "Item ID", value: id),
                        tmdbID.map { .init(label: "TMDB ID", value: $0) }
                    ]
                    .compactMap { $0 }
                )
            ] + (detailSections ?? []),
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
