import Foundation

enum AppRoute: Hashable {
    case plexSetup
    case jellyfinSetup
    case plexSettings
    case jellyfinSettings
    case movieLibrary(String)
    case movie(PlexMediaItem)
    case tvLibrary(String)
    case series(String)
    case season(String)
    case episode(String)
    case otherLibrary(String)
    case other(String)
}
