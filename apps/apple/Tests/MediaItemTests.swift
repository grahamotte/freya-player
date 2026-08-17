import Foundation
import XCTest
@testable import FreyaPlayerCore

final class MediaItemTests: XCTestCase {
    func testFormattingPlaybackAndResumeState() {
        let item = makeMediaItem(durationMilliseconds: 5_400_000, progress: 0.4, resumeOffsetMilliseconds: 12_000)

        XCTAssertEqual(item.runtimeText, "1h 30m")
        XCTAssertTrue(item.hasResume)
        XCTAssertEqual(item.playButtonTitle, "Resume at 0:12")
        XCTAssertEqual(item.playbackID?.itemID, item.id)
        XCTAssertEqual(item.artworkURL, item.artwork.posterURL)
        XCTAssertEqual(MediaItemKind.episode.artworkStyle, .landscape)
        XCTAssertFalse(MediaItemKind.season.isPlayable)
        XCTAssertEqual(
            makeMediaItem(resumeOffsetMilliseconds: 3_723_000).playButtonTitle,
            "Resume at 1:02:03"
        )
    }

    func testWatchStatusAndDerivedProgress() {
        let item = makeMediaItem(progress: 0.5, resumeOffsetMilliseconds: 2_000)
        let watched = item.settingWatchStatus(true)
        let stats = MediaItem.derivedWatchStats(fromLeaves: [watched, item])

        XCTAssertTrue(watched.isWatched)
        XCTAssertEqual(watched.progress, 1)
        XCTAssertNil(watched.resumeOffsetMilliseconds)
        XCTAssertFalse(stats.isWatched)
        XCTAssertEqual(stats.progress, 0.75)
    }

    func testLatestAddedAtUsesNewestEpisode() {
        let show = makeMediaItem(kind: .series, addedAt: 50)
        let episodes = [
            makeMediaItem(kind: .episode, addedAt: 100),
            makeMediaItem(kind: .episode, addedAt: 300),
            makeMediaItem(kind: .episode, addedAt: 200),
            makeMediaItem(kind: .movie, addedAt: 400),
        ]

        XCTAssertEqual(show.applyingLatestEpisodeAddedAt(from: episodes).addedAt, 300)
    }

    func testPreservesCachedSeriesAddedAtAcrossMetadataRefreshes() {
        let cached = makeMediaItem(kind: .series, addedAt: 300)
        let refreshed = makeMediaItem(kind: .series, addedAt: 50)
        let movie = makeMediaItem(kind: .movie, addedAt: 50)

        XCTAssertEqual(refreshed.preservingNewerSeriesAddedAt(from: cached).addedAt, 300)
        XCTAssertEqual(movie.preservingNewerSeriesAddedAt(from: cached).addedAt, 50)
    }
}

func makeMediaItem(
    id: String = "item",
    title: String = "Movie",
    kind: MediaItemKind = .movie,
    addedAt: Int? = 100,
    durationMilliseconds: Int? = 60_000,
    isWatched: Bool = false,
    progress: Double? = nil,
    resumeOffsetMilliseconds: Int? = nil
) -> MediaItem {
    MediaItem(
        providerID: .plex,
        serverID: "server",
        id: id,
        title: title,
        kind: kind,
        synopsis: "Synopsis",
        addedAt: addedAt,
        releasedAt: nil,
        year: 2026,
        durationMilliseconds: durationMilliseconds,
        contentRating: nil,
        tmdbID: nil,
        isWatched: isWatched,
        progress: progress,
        resumeOffsetMilliseconds: resumeOffsetMilliseconds,
        artwork: MediaArtworkSet(
            posterURL: URL(string: "https://example.com/poster"),
            thumbnailURL: URL(string: "https://example.com/thumbnail"),
            landscapeURL: URL(string: "https://example.com/landscape"),
            backdropURL: URL(string: "https://example.com/backdrop")
        ),
        detailSections: nil
    )
}

func makeLibraryReference(id: String = "library") -> LibraryReference {
    LibraryReference(
        providerID: .plex,
        serverID: "server",
        id: id,
        title: "Movies",
        itemTitle: "Movie",
        artworkStyle: .poster,
        defaultItemKind: .movie
    )
}

func makeLibraryShelf(id: String = "library", items: [MediaItem] = [], isHidden: Bool = false) -> LibraryShelf {
    LibraryShelf(
        id: id,
        title: "Movies",
        reference: makeLibraryReference(id: id),
        items: items,
        isHidden: isHidden
    )
}
