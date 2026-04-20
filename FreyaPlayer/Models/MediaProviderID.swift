import Foundation

enum MediaProviderID: String, Hashable {
    case plex
    case jellyfin

    var title: String {
        switch self {
        case .plex:
            return "Plex"
        case .jellyfin:
            return "Jellyfin"
        }
    }
}
