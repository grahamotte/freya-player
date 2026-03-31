import Foundation

enum AppRoute: Hashable {
    case plexSetup
    case jellyfinSetup
    case plexSettings
    case jellyfinSettings
    case library(PlexLibraryContext)
    case movie(PlexMediaItem)
    case series(PlexMediaItem)
    case season(PlexMediaItem)
    case episode(PlexMediaItem)
    case other(PlexMediaItem)
}

extension PlexLibraryContext {
    var route: AppRoute {
        .library(self)
    }

    func itemRoute(for item: PlexMediaItem) -> AppRoute {
        if type == "show" {
            return .series(item)
        }

        return usesPosterArtwork ? .movie(item) : .other(item)
    }
}
