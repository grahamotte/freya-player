import Foundation
import XCTest
@testable import FreyaPlayerCore

final class LibraryCacheTests: XCTestCase {
    @MainActor
    func testLoadedCacheDerivesAndKeepsSeriesAddedAt() throws {
        let cachedSeries = makeMediaItem(id: "series", kind: .series, addedAt: 500)
        let library = makeLibraryShelf(items: [cachedSeries])
        let season = makeMediaItem(id: "season", kind: .season, addedAt: 50)
        let episodes = [
            makeMediaItem(id: "older", kind: .episode, addedAt: 100),
            makeMediaItem(id: "newer", kind: .episode, addedAt: 300),
        ]
        let snapshot = LibraryCacheSnapshot(
            serverKey: "plex:server",
            libraries: [
                library.id: CachedLibrary(reference: library.reference, isHidden: false),
            ],
            libraryOrder: [library.id],
            itemsByID: [
                "series": cachedSeries,
                "season": season,
                "older": episodes[0],
                "newer": episodes[1],
            ],
            libraryItemIDs: [library.id: ["series"]],
            childItemIDs: [
                "series": ["season"],
                "season": ["older", "newer"],
            ],
            derivedSeriesAddedAtVersion: nil
        )
        let storedData = try JSONEncoder().encode(snapshot)
        let storedSnapshot = try JSONDecoder().decode(LibraryCacheSnapshot.self, from: storedData)
        var savedSnapshot: LibraryCacheSnapshot?
        let storage = LibraryCacheStorage(
            load: { storedSnapshot },
            save: { savedSnapshot = $0 },
            clear: {},
            sizeBytes: { 0 }
        )
        let cache = LibraryCache(storage: storage)
        let refreshedLibrary = library.settingItems([
            makeMediaItem(id: "series", kind: .series, addedAt: 500),
        ])
        let server = ConnectedServer(
            providerID: .plex,
            serverID: "server",
            serverName: "Server",
            serverURL: "https://example.com",
            accountName: "Account",
            libraries: [refreshedLibrary]
        )

        cache.install(server: server)
        let installedData = try JSONEncoder().encode(cache.snapshot)
        let installedSnapshot = try JSONDecoder().decode(LibraryCacheSnapshot.self, from: installedData)

        XCTAssertEqual(cache.libraryItems(for: library.id).first?.addedAt, 300)
        XCTAssertEqual(savedSnapshot?.itemsByID["series"]?.addedAt, 300)
        XCTAssertEqual(savedSnapshot?.derivedSeriesAddedAtVersion, 1)
        XCTAssertEqual(installedSnapshot.serverMetadata?.serverName, "Server")
        XCTAssertEqual(installedSnapshot.serverMetadata?.serverURL, "https://example.com")
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
