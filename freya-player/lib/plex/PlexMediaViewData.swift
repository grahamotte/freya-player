import Foundation

extension PlexMediaItem {
    func mediaViewData(
        in summary: PlexConnectionSummary,
        playbackID: MediaPlaybackID? = nil
    ) -> MediaViewData {
        MediaViewData(
            title: title,
            metadata: [
                year.map { .init(label: "Year", value: String($0)) },
                runtimeText.map { .init(label: "Length", value: $0) },
                contentRating.map { .init(label: "Rating", value: $0) }
            ]
            .compactMap { $0 },
            synopsis: synopsis,
            posterURL: artworkURL(
                baseURL: summary.serverURL,
                token: summary.serverToken,
                width: 720,
                height: 1080
            ),
            backdropURL: artworkURL(
                baseURL: summary.serverURL,
                token: summary.serverToken,
                width: 1920,
                height: 1080,
                preferCoverArt: true
            ),
            playbackID: playbackID
        )
    }
}
