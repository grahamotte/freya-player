import Foundation
import XCTest
@testable import FreyaPlayerCore

final class LibraryCacheTests: XCTestCase {
    @MainActor
    func testLoadedCacheWithoutCurrentVersionIsCleared() {
        for cacheVersion in [nil, 0] as [Int?] {
            let series = makeMediaItem(id: "series", kind: .series)
            let library = makeLibraryShelf(items: [series])
            let snapshot = LibraryCacheSnapshot(
                cacheVersion: cacheVersion,
                serverKey: "plex:server",
                libraries: [
                    library.id: CachedLibrary(reference: library.reference, isHidden: false),
                ],
                libraryOrder: [library.id],
                itemsByID: [series.id: series],
                libraryItemIDs: [library.id: [series.id]]
            )
            var didClear = false
            var storedSnapshot: LibraryCacheSnapshot? = snapshot
            let cache = LibraryCache(
                storage: LibraryCacheStorage(
                    load: { storedSnapshot },
                    save: { _ in },
                    clear: {
                        didClear = true
                        storedSnapshot = nil
                    },
                    sizeBytes: { 0 }
                )
            )

            XCTAssertTrue(didClear)
            XCTAssertTrue(cache.snapshot.isEmpty)
            XCTAssertEqual(cache.applicationCacheVersion, LibraryCacheSnapshot.currentVersion)
            XCTAssertNil(cache.fileCacheVersion)
            XCTAssertEqual(cache.snapshot.cacheVersion, LibraryCacheSnapshot.currentVersion)
            XCTAssertNil(cache.cachedServer())
        }
    }

    @MainActor
    func testLoadedSeriesOrderStaysStableAfterRefresh() {
        let olderSeries = makeMediaItem(id: "older-series", title: "Older", kind: .series, addedAt: 100)
        let newerSeries = makeMediaItem(id: "newer-series", title: "Newer", kind: .series, addedAt: 300)
        let olderSeason = makeMediaItem(id: "older-season", kind: .season)
        let newerSeason = makeMediaItem(id: "newer-season", kind: .season)
        let olderEpisode = makeMediaItem(id: "older-episode", kind: .episode, addedAt: 100)
        let newerEpisode = makeMediaItem(id: "newer-episode", kind: .episode, addedAt: 300)
        let library = makeLibraryShelf(items: [olderSeries, newerSeries])
        let storedSnapshot = LibraryCacheSnapshot(
            serverKey: "plex:server",
            libraries: [
                library.id: CachedLibrary(reference: library.reference, isHidden: false),
            ],
            libraryOrder: [library.id],
            itemsByID: [
                olderSeries.id: olderSeries,
                newerSeries.id: newerSeries,
                olderSeason.id: olderSeason,
                newerSeason.id: newerSeason,
                olderEpisode.id: olderEpisode,
                newerEpisode.id: newerEpisode,
            ],
            libraryItemIDs: [library.id: [olderSeries.id, newerSeries.id]],
            childItemIDs: [
                olderSeries.id: [olderSeason.id],
                newerSeries.id: [newerSeason.id],
                olderSeason.id: [olderEpisode.id],
                newerSeason.id: [newerEpisode.id],
            ]
        )
        let cache = LibraryCache(
            storage: LibraryCacheStorage(
                load: { storedSnapshot },
                save: { _ in },
                clear: {},
                sizeBytes: { 0 }
            )
        )
        let refreshedOlderSeries = makeMediaItem(
            id: olderSeries.id,
            title: olderSeries.title,
            kind: .series,
            addedAt: 500
        )
        let refreshedNewerSeries = makeMediaItem(
            id: newerSeries.id,
            title: newerSeries.title,
            kind: .series,
            addedAt: 400
        )

        XCTAssertEqual(cache.applicationCacheVersion, LibraryCacheSnapshot.currentVersion)
        XCTAssertEqual(cache.fileCacheVersion, LibraryCacheSnapshot.currentVersion)

        let initialOrder = LibraryPageSort.addedAt.items(
            from: cache.libraryItems(for: library.id),
            order: .descending
        ).map(\.id)

        cache.beginBatchUpdates()
        cache.ingest(items: [refreshedOlderSeries, refreshedNewerSeries], asTopLevelOf: library.id)
        cache.ingest(children: [olderSeason], of: olderSeries.id)
        cache.ingest(children: [newerSeason], of: newerSeries.id)
        cache.ingest(children: [olderEpisode], of: olderSeason.id)
        cache.ingest(children: [newerEpisode], of: newerSeason.id)
        cache.cacheLatestEpisodeAddedAt(for: [olderSeries.id, newerSeries.id])
        cache.endBatchUpdates()

        let refreshedOrder = LibraryPageSort.addedAt.items(
            from: cache.libraryItems(for: library.id),
            order: .descending
        ).map(\.id)

        XCTAssertEqual(initialOrder, [newerSeries.id, olderSeries.id])
        XCTAssertEqual(refreshedOrder, initialOrder)
        XCTAssertEqual(cache.snapshot.itemsByID[olderSeries.id]?.addedAt, 100)
        XCTAssertEqual(cache.snapshot.itemsByID[newerSeries.id]?.addedAt, 300)
    }

    @MainActor
    func testLoadedLegacyCacheBuildsBrowsableServerWithChildren() throws {
        let series = makeMediaItem(id: "series", kind: .series)
        let season = makeMediaItem(id: "season", kind: .season)
        let episode = makeMediaItem(id: "episode", kind: .episode)
        let library = makeLibraryShelf(items: [series])
        let snapshot = LibraryCacheSnapshot(
            serverKey: "plex:server",
            libraries: [
                library.id: CachedLibrary(reference: library.reference, isHidden: false),
            ],
            libraryOrder: [library.id],
            itemsByID: [
                series.id: series,
                season.id: season,
                episode.id: episode,
            ],
            libraryItemIDs: [library.id: [series.id]],
            childItemIDs: [
                series.id: [season.id],
                season.id: [episode.id],
            ]
        )
        let data = try JSONEncoder().encode(snapshot)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["serverMetadata"] = nil
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let legacySnapshot = try JSONDecoder().decode(LibraryCacheSnapshot.self, from: legacyData)
        let cache = LibraryCache(
            storage: LibraryCacheStorage(
                load: { legacySnapshot },
                save: { _ in },
                clear: {},
                sizeBytes: { Int64(legacyData.count) }
            )
        )

        let server = try XCTUnwrap(cache.cachedServer())

        XCTAssertEqual(server.providerID, .plex)
        XCTAssertEqual(server.serverID, "server")
        XCTAssertEqual(server.serverName, "Plex")
        XCTAssertEqual(server.libraries.map(\.id), [library.id])
        XCTAssertEqual(cache.children(of: series.id).map(\.id), [season.id])
        XCTAssertEqual(cache.children(of: season.id).map(\.id), [episode.id])
    }

    @MainActor
    func testRefreshBatchKeepsCompletedSnapshotVisibleAndStoresEpisodeMaximum() {
        let series = makeMediaItem(id: "series", kind: .series, addedAt: 300)
        let oldSeason = makeMediaItem(id: "old-season", kind: .season)
        let oldEpisode = makeMediaItem(id: "old-episode", kind: .episode, addedAt: 300)
        let library = makeLibraryShelf(items: [series])
        let snapshot = LibraryCacheSnapshot(
            serverKey: "plex:server",
            libraries: [
                library.id: CachedLibrary(reference: library.reference, isHidden: false),
            ],
            libraryOrder: [library.id],
            itemsByID: [
                series.id: series,
                oldSeason.id: oldSeason,
                oldEpisode.id: oldEpisode,
            ],
            libraryItemIDs: [library.id: [series.id]],
            childItemIDs: [
                series.id: [oldSeason.id],
                oldSeason.id: [oldEpisode.id],
            ]
        )
        let storage = LibraryCacheStorage(
            load: { snapshot },
            save: { _ in },
            clear: {},
            sizeBytes: { 0 }
        )
        let cache = LibraryCache(storage: storage)
        let refreshedSeries = makeMediaItem(id: series.id, kind: .series, addedAt: 500)
        let newSeason = makeMediaItem(id: "new-season", kind: .season)
        let newEpisode = makeMediaItem(id: "new-episode", kind: .episode, addedAt: 200)

        cache.beginBatchUpdates()
        cache.ingest(items: [refreshedSeries], asTopLevelOf: library.id)
        cache.ingest(children: [newSeason], of: series.id)

        XCTAssertEqual(cache.libraryItems(for: library.id).first?.addedAt, 300)

        cache.ingest(children: [newEpisode], of: newSeason.id)
        cache.cacheLatestEpisodeAddedAt(for: [series.id])

        XCTAssertEqual(cache.libraryItems(for: library.id).first?.addedAt, 300)

        cache.endBatchUpdates()

        XCTAssertEqual(cache.libraryItems(for: library.id).first?.addedAt, 200)
        XCTAssertEqual(cache.snapshot.itemsByID[series.id]?.addedAt, 200)
        XCTAssertNil(cache.snapshot.itemsByID[oldEpisode.id])
    }
}
