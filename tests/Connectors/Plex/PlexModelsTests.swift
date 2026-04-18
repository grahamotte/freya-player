import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class PlexModelsTests: XCTestCase {
    func testLibraryContextMapsPosterAndItemKinds() {
        let show = PlexLibraryContext(id: "1", title: "Shows", type: "show", agent: nil)
        let movies = PlexLibraryContext(id: "2", title: "Movies", type: "movie", agent: "tv.plex.agents.movie")
        let files = PlexLibraryContext(id: "3", title: "Files", type: "movie", agent: "tv.plex.agents.none")

        XCTAssertTrue(show.usesPosterArtwork)
        XCTAssertEqual(show.itemName, "show")
        XCTAssertEqual(show.defaultItemKind, .series)
        XCTAssertEqual(movies.libraryReference(providerID: .plex, serverID: "server").artworkStyle, .poster)
        XCTAssertEqual(files.libraryReference(providerID: .plex, serverID: "server").defaultItemKind, .other)
    }

    func testPlexMediaItemDecodesLossyFieldsAndMapsArtwork() throws {
        let item = try JSONDecoder().decode(
            PlexMediaItem.self,
            from: jsonBody([
                "ratingKey": 7,
                "type": "movie",
                "title": "Movie",
                "summary": "",
                "addedAt": "10",
                "year": "2023",
                "duration": "600000",
                "viewOffset": "300000",
                "contentRating": "PG",
                "thumb": "/thumb.jpg",
                "art": "/art.jpg"
            ])
        )
        let mediaItem = item.mediaItem(
            providerID: .plex,
            serverID: "server",
            serverURL: "https://plex.local",
            serverToken: "token",
            fallbackKind: .movie
        )

        XCTAssertEqual(item.synopsis, "No description available.")
        XCTAssertEqual(mediaItem.id, "7")
        XCTAssertEqual(mediaItem.kind, .movie)
        XCTAssertEqual(mediaItem.progress, 0.5)
        XCTAssertEqual(mediaItem.resumeOffsetMilliseconds, 300_000)
        XCTAssertEqual(mediaItem.artwork.posterURL?.absoluteString, "https://plex.local/photo/:/transcode?url=/thumb.jpg&width=480&height=720&minSize=1&upscale=1&X-Plex-Token=token")
        XCTAssertEqual(mediaItem.artwork.backdropURL?.absoluteString, "https://plex.local/photo/:/transcode?url=/art.jpg&width=1920&height=1080&minSize=1&upscale=1&X-Plex-Token=token")
    }

    func testPlexMediaItemUsesLeafCountsForCollectionProgress() throws {
        let item = try JSONDecoder().decode(
            PlexMediaItem.self,
            from: jsonBody([
                "ratingKey": "series",
                "type": "show",
                "title": "Show",
                "leafCount": 10,
                "viewedLeafCount": 4
            ])
        )

        XCTAssertFalse(item.isWatched)
        XCTAssertEqual(item.progress, 0.4)
        XCTAssertEqual(item.mediaItem(providerID: .plex, serverID: "server", serverURL: "https://plex.local", serverToken: "token", fallbackKind: .series).kind, .series)
    }
}
