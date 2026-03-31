import Foundation

extension MediaItem {
    func mediaViewData() -> MediaViewData {
        MediaViewData(
            title: title,
            metadata: [
                year.map { .init(label: "Year", value: String($0)) },
                runtimeText.map { .init(label: "Length", value: $0) },
                contentRating.map { .init(label: "Rating", value: $0) }
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
