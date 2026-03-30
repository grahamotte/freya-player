import Foundation

enum AppRoute: Hashable {
    case plexSetup
    case jellyfinSetup
    case plexSettings
    case jellyfinSettings
    case movieLibrary(String)
    case movie(PlexMediaItem)
    case tvLibrary(String)
    case series(PlexMediaItem)
    case season(PlexMediaItem)
    case episode(PlexMediaItem)
    case otherLibrary(String)
    case other(PlexMediaItem)
}
