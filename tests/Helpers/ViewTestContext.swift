import SwiftUI
import XCTest

#if os(tvOS)
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif
#else
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif
#endif

struct ViewTestContext {
    let model: AppModel
    let path: Binding<[AppRoute]>
    let server: ConnectedServer
    let movieLibrary: LibraryReference
    let showLibrary: LibraryReference
    let otherLibrary: LibraryReference
    let movie: MediaItem
    let episode: MediaItem
    let season: MediaItem
    let series: MediaItem
    let other: MediaItem
}

@MainActor
func makeViewTestContext(testCase: XCTestCase) -> ViewTestContext {
    let movie = makeMediaItem(providerID: .jellyfin, id: "movie", kind: .movie)
    let episode = makeMediaItem(providerID: .jellyfin, id: "episode", kind: .episode)
    let season = makeMediaItem(providerID: .jellyfin, id: "season", kind: .season)
    let series = makeMediaItem(providerID: .jellyfin, id: "series", kind: .series)
    let other = makeMediaItem(providerID: .jellyfin, id: "other", kind: .other)
    let movieLibrary = makeLibraryReference(
        providerID: .jellyfin,
        id: "movies",
        title: "Movies",
        itemTitle: "movie",
        artworkStyle: .poster,
        defaultItemKind: .movie
    )
    let showLibrary = makeLibraryReference(
        providerID: .jellyfin,
        id: "shows",
        title: "Shows",
        itemTitle: "show",
        artworkStyle: .poster,
        defaultItemKind: .series
    )
    let otherLibrary = makeLibraryReference(
        providerID: .jellyfin,
        id: "other",
        title: "Other",
        itemTitle: "item",
        artworkStyle: .landscape,
        defaultItemKind: .other
    )
    let jellyfin = FakeJellyfinConnector()
    jellyfin.restoreConnectionResult = .success(nil)
    jellyfin.itemsByID[movie.id] = movie
    jellyfin.itemsByID[episode.id] = episode
    jellyfin.itemsByID[season.id] = season
    jellyfin.itemsByID[series.id] = series
    jellyfin.itemsByID[other.id] = other
    jellyfin.childrenByID[series.id] = .success([season])
    jellyfin.childrenByID[season.id] = .success([episode])
    jellyfin.libraryItemsByID[movieLibrary.id] = [movie]
    jellyfin.libraryItemsByID[showLibrary.id] = [series]
    jellyfin.libraryItemsByID[otherLibrary.id] = [other]

    let model = AppModel(
        mediaSessionStore: MediaSessionStore(defaults: makeDefaults(testCase: testCase)),
        plexConnector: FakePlexConnector(),
        jellyfinConnector: jellyfin
    )
    let server = makeConnectedServer(
        providerID: .jellyfin,
        libraries: [
            makeLibraryShelf(id: movieLibrary.id, title: movieLibrary.title, reference: movieLibrary, items: [movie]),
            makeLibraryShelf(id: showLibrary.id, title: showLibrary.title, reference: showLibrary, items: [series]),
            makeLibraryShelf(id: otherLibrary.id, title: otherLibrary.title, reference: otherLibrary, items: [other])
        ]
    )

    return ViewTestContext(
        model: model,
        path: .constant([]),
        server: server,
        movieLibrary: movieLibrary,
        showLibrary: showLibrary,
        otherLibrary: otherLibrary,
        movie: movie,
        episode: episode,
        season: season,
        series: series,
        other: other
    )
}
