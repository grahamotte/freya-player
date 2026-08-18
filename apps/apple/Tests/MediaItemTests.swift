import Foundation
import XCTest
@testable import FreyaPlayerCore

final class MediaItemTests: XCTestCase {
    func testFormattingPlaybackAndResumeState() {
        let item = makeMediaItem(durationMilliseconds: 5_400_000, progress: 0.4, resumeOffsetMilliseconds: 12_000)

        XCTAssertEqual(item.runtimeText, "1h 30m")
        XCTAssertTrue(item.hasResume)
        XCTAssertEqual(item.playButtonTitle, "Resume at 0:12")
        XCTAssertEqual(item.quickPlayButtonTitle, "Resume Now")
        XCTAssertEqual(item.playbackID?.itemID, item.id)
        XCTAssertEqual(item.artworkURL, item.artwork.posterURL)
        XCTAssertEqual(MediaItemKind.episode.artworkStyle, .landscape)
        XCTAssertFalse(MediaItemKind.season.isPlayable)
        XCTAssertEqual(
            makeMediaItem(resumeOffsetMilliseconds: 3_723_000).playButtonTitle,
            "Resume at 1:02:03"
        )
        XCTAssertEqual(makeMediaItem().quickPlayButtonTitle, "Play Now")
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

    func testApplyingPlaybackProgressUpdatesResumeState() {
        let item = makeMediaItem(
            durationMilliseconds: 100_000,
            progress: 0.1,
            resumeOffsetMilliseconds: 10_000
        )
        let updated = item.applyingPlaybackProgress(time: 45_000, duration: 90_000)

        XCTAssertFalse(updated.isWatched)
        XCTAssertEqual(updated.progress, 0.5)
        XCTAssertEqual(updated.resumeOffsetMilliseconds, 45_000)
    }

    func testApplyingPlaybackProgressUsesItemDurationAndPreservesWatchedState() {
        let item = makeMediaItem(durationMilliseconds: 100_000)
        let updated = item.applyingPlaybackProgress(time: 25_000, duration: nil)
        let watched = item.settingWatchStatus(true)
        let reset = makeMediaItem(progress: 0.5, resumeOffsetMilliseconds: 50_000)
            .applyingPlaybackProgress(time: 0, duration: 100_000)

        XCTAssertEqual(updated.progress, 0.25)
        XCTAssertEqual(updated.resumeOffsetMilliseconds, 25_000)
        XCTAssertEqual(watched.applyingPlaybackProgress(time: 25_000, duration: 100_000), watched)
        XCTAssertNil(reset.progress)
        XCTAssertNil(reset.resumeOffsetMilliseconds)
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
        XCTAssertNil(show.applyingLatestEpisodeAddedAt(from: []).addedAt)
    }

    func testSeriesUsesCachedDerivedAddedAtInsteadOfProviderDate() {
        let cached = makeMediaItem(kind: .series, addedAt: 300)
        let refreshed = makeMediaItem(kind: .series, addedAt: 500)
        let movie = makeMediaItem(kind: .movie, addedAt: 500)

        XCTAssertEqual(refreshed.usingCachedSeriesAddedAt(from: cached).addedAt, 300)
        XCTAssertNil(refreshed.usingCachedSeriesAddedAt(from: nil).addedAt)
        XCTAssertEqual(movie.usingCachedSeriesAddedAt(from: cached).addedAt, 500)
    }

    func testQuickPlaySelectsFirstPartiallyPlayedOrUnplayedEpisodeInOrder() {
        let series = makeMediaItem(kind: .series)
        let episodes = [
            makeMediaItem(id: "watched", kind: .episode, isWatched: true),
            makeMediaItem(
                id: "partial",
                kind: .episode,
                progress: 0.5,
                resumeOffsetMilliseconds: 30_000
            ),
            makeMediaItem(id: "unplayed", kind: .episode),
        ]

        XCTAssertEqual(series.quickPlayItem(from: episodes)?.id, "partial")
        XCTAssertEqual(series.quickPlayItem(from: episodes)?.quickPlayButtonTitle, "Resume Now")
    }

    func testQuickPlaySupportsPlayableItemsAndRejectsOtherContainers() {
        let movie = makeMediaItem(kind: .movie)
        let watchedEpisode = makeMediaItem(kind: .episode, isWatched: true)

        XCTAssertEqual(movie.quickPlayItem(from: []), movie)
        XCTAssertNil(makeMediaItem(kind: .series).quickPlayItem(from: [watchedEpisode]))
        XCTAssertNil(makeMediaItem(kind: .season).quickPlayItem(from: []))
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
