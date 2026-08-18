import XCTest
@testable import FreyaPlayerCore

final class LibraryCacheTests: XCTestCase {
    @MainActor
    func testInstalledServerUsesCachedEpisodesForSeriesAddedAt() {
        let library = makeLibraryShelf(items: [
            makeMediaItem(id: "series", kind: .series, addedAt: 50),
        ])
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
                "series": library.items[0],
                "season": season,
                "older": episodes[0],
                "newer": episodes[1],
            ],
            libraryItemIDs: [library.id: ["series"]],
            childItemIDs: [
                "series": ["season"],
                "season": ["older", "newer"],
            ]
        )
        let storage = LibraryCacheStorage(
            load: { snapshot },
            save: { _ in },
            clear: {},
            sizeBytes: { 0 }
        )
        let cache = LibraryCache(storage: storage)
        let server = ConnectedServer(
            providerID: .plex,
            serverID: "server",
            serverName: "Server",
            serverURL: "https://example.com",
            accountName: "Account",
            libraries: [library]
        )

        cache.install(server: server)

        XCTAssertEqual(cache.libraryItems(for: library.id).first?.addedAt, 300)
    }
}
