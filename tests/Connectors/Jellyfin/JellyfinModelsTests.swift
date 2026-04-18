import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class JellyfinModelsTests: XCTestCase {
    func testJellyfinLibraryMapsCollectionTypes() {
        let movies = JellyfinLibrary(id: "movies", title: "Movies", collectionType: "movies", items: [])
        let shows = JellyfinLibrary(id: "shows", title: "Shows", collectionType: "tvshows", items: [])
        let other = JellyfinLibrary(id: "other", title: "Other", collectionType: "folders", items: [])

        XCTAssertEqual(movies.libraryReference(providerID: .jellyfin, serverID: "server").defaultItemKind, .movie)
        XCTAssertEqual(shows.libraryReference(providerID: .jellyfin, serverID: "server").itemTitle, "show")
        XCTAssertEqual(other.libraryReference(providerID: .jellyfin, serverID: "server").artworkStyle, .landscape)
    }

    func testJellyfinItemMapsWatchStateProgressAndArtwork() {
        let item = JellyfinItem(
            id: "episode",
            name: "Episode",
            type: "Episode",
            collectionType: nil,
            overview: "",
            dateCreated: "2024-04-01T12:00:00Z",
            productionYear: 2024,
            runTimeTicks: 2_000_000_000,
            officialRating: "TV-14",
            userData: JellyfinUserData(
                playedPercentage: nil,
                unplayedItemCount: nil,
                playbackPositionTicks: 1_000_000_000,
                playCount: 0,
                played: false
            ),
            imageTags: ["Thumb": "thumb-tag"],
            backdropImageTags: ["backdrop-tag"],
            parentBackdropItemId: nil,
            parentBackdropImageTags: nil,
            parentThumbItemId: nil,
            parentThumbImageTag: nil,
            parentPrimaryImageItemId: nil,
            parentPrimaryImageTag: nil,
            seriesId: "series",
            seriesPrimaryImageTag: "series-poster"
        )

        let mediaItem = item.mediaItem(
            providerID: .jellyfin,
            serverID: "server",
            serverURL: "https://jellyfin.local",
            accessToken: "token",
            fallbackKind: .episode
        )

        XCTAssertEqual(mediaItem.synopsis, "No description available.")
        XCTAssertEqual(mediaItem.kind, .episode)
        XCTAssertEqual(mediaItem.addedAt, 1_711_972_800)
        XCTAssertEqual(mediaItem.progress, 0.5)
        XCTAssertEqual(mediaItem.resumeOffsetMilliseconds, 100_000)
        XCTAssertEqual(mediaItem.artwork.landscapeURL?.absoluteString, "https://jellyfin.local/Items/episode/Images/Thumb?tag=thumb-tag&maxWidth=780&maxHeight=439&quality=90&api_key=token")
        XCTAssertEqual(mediaItem.backdropURL?.absoluteString, mediaItem.artwork.landscapeURL?.absoluteString)
    }

    func testJellyfinMoviePrefersPosterAndBackdropCandidates() {
        let item = JellyfinItem(
            id: "movie",
            name: "Movie",
            type: "Movie",
            collectionType: nil,
            overview: "Overview",
            dateCreated: "2024-04-01T12:00:00.250Z",
            productionYear: 2024,
            runTimeTicks: nil,
            officialRating: nil,
            userData: JellyfinUserData(playedPercentage: 75, unplayedItemCount: nil, playbackPositionTicks: 0, playCount: 0, played: false),
            imageTags: ["Primary": "poster"],
            backdropImageTags: ["backdrop"],
            parentBackdropItemId: nil,
            parentBackdropImageTags: nil,
            parentThumbItemId: nil,
            parentThumbImageTag: nil,
            parentPrimaryImageItemId: nil,
            parentPrimaryImageTag: nil,
            seriesId: nil,
            seriesPrimaryImageTag: nil
        )

        let mediaItem = item.mediaItem(
            providerID: .jellyfin,
            serverID: "server",
            serverURL: "https://jellyfin.local",
            accessToken: "token",
            fallbackKind: .movie
        )

        XCTAssertEqual(mediaItem.progress, 0.75)
        XCTAssertEqual(mediaItem.artwork.posterURL?.absoluteString, "https://jellyfin.local/Items/movie/Images/Primary?tag=poster&maxWidth=480&maxHeight=720&quality=90&api_key=token")
        XCTAssertEqual(mediaItem.artwork.backdropURL?.absoluteString, "https://jellyfin.local/Items/movie/Images/Backdrop/0?tag=backdrop&maxWidth=1920&maxHeight=1080&quality=90&api_key=token")
    }

    func testJellyfinDateParserHandlesFractionalAndPlainDates() {
        XCTAssertNotNil(JellyfinDateParser.parse("2024-04-01T12:00:00Z"))
        XCTAssertNotNil(JellyfinDateParser.parse("2024-04-01T12:00:00.250Z"))
        XCTAssertNil(JellyfinDateParser.parse("not-a-date"))
    }
}
