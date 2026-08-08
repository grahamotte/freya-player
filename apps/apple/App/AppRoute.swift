import Foundation

enum AppRoute: Hashable {
    case plexSetup
    case jellyfinSetup
    case about
    case plexSettings
    case jellyfinSettings
    case library(LibraryReference)
    case movie(MediaItem)
    case series(MediaItem)
    case season(MediaItem)
    case episode(MediaItem)
    case other(MediaItem)
}

extension LibraryReference {
    var route: AppRoute {
        .library(self)
    }
}

extension MediaItem {
    var route: AppRoute {
        switch kind {
        case .movie:
            return .movie(self)
        case .series:
            return .series(self)
        case .season:
            return .season(self)
        case .episode:
            return .episode(self)
        case .other:
            return .other(self)
        }
    }
}

extension MediaProviderID {
    var settingsRoute: AppRoute {
        switch self {
        case .plex:
            return .plexSettings
        case .jellyfin:
            return .jellyfinSettings
        }
    }
}
