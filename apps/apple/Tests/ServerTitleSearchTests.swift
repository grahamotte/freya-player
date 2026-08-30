import XCTest
@testable import FreyaPlayerCore

final class ServerTitleSearchTests: XCTestCase {
    @MainActor
    func testSearchRanksMatchesAcrossVisibleServerLibraries() {
        let batman = makeMediaItem(id: "batman", title: "Batman")
        let arrival = makeMediaItem(id: "arrival", title: "Arrival")
        let movies = makeLibraryShelf(id: "movies", items: [arrival])
        let favorites = makeLibraryShelf(id: "favorites", items: [batman])
        let server = makeServer(libraries: [movies, favorites])
        let cache = makeCache(shelves: [movies, favorites], items: [batman, arrival])
        let search = ServerTitleSearch(cache: cache, server: server)

        search.query = "btmn"

        XCTAssertEqual(search.results.first?.item.id, "batman")
        XCTAssertFalse(search.results.contains { $0.item.id == "arrival" })
        XCTAssertFalse(search.results.first?.matchedRanges.isEmpty ?? true)
    }

    @MainActor
    func testSearchUsesDescendantsAndExcludesHiddenLibraries() {
        let series = makeMediaItem(id: "series", title: "Dark", kind: .series)
        let season = makeMediaItem(id: "season", title: "Season One", kind: .season)
        let episode = makeMediaItem(id: "episode", title: "Secrets", kind: .episode)
        let hidden = makeMediaItem(id: "hidden", title: "Secret Window")
        let shows = makeLibraryShelf(id: "shows", items: [series])
        let hiddenShelf = makeLibraryShelf(id: "hidden-library", items: [hidden], isHidden: true)
        let server = makeServer(libraries: [shows, hiddenShelf])
        let cache = makeCache(
            shelves: [shows, hiddenShelf],
            items: [series, season, episode, hidden],
            childItemIDs: [
                series.id: [season.id],
                season.id: [episode.id],
            ]
        )
        let search = ServerTitleSearch(cache: cache, server: server)

        search.query = "secrt"

        XCTAssertEqual(search.results.first?.item.id, episode.id)
        XCTAssertFalse(search.results.contains { $0.item.id == hidden.id })

        search.query = "   "
        XCTAssertTrue(search.results.isEmpty)
    }

    private func makeServer(libraries: [LibraryShelf]) -> ConnectedServer {
        ConnectedServer(
            providerID: .plex,
            serverID: "server",
            serverName: "Home",
            serverURL: "https://example.com",
            accountName: "Account",
            libraries: libraries
        )
    }

    @MainActor
    private func makeCache(
        shelves: [LibraryShelf],
        items: [MediaItem],
        childItemIDs: [String: [String]] = [:]
    ) -> LibraryCache {
        let snapshot = LibraryCacheSnapshot(
            serverKey: "plex:server",
            libraries: Dictionary(
                uniqueKeysWithValues: shelves.map {
                    ($0.id, CachedLibrary(reference: $0.reference, isHidden: $0.isHidden))
                }
            ),
            libraryOrder: shelves.map(\.id),
            itemsByID: Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) }),
            libraryItemIDs: Dictionary(uniqueKeysWithValues: shelves.map { ($0.id, $0.items.map(\.id)) }),
            childItemIDs: childItemIDs
        )
        return LibraryCache(
            storage: LibraryCacheStorage(
                load: { snapshot },
                save: { _ in },
                clear: {},
                sizeBytes: { 0 }
            )
        )
    }
}
