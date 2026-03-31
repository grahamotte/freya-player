import Foundation

enum MediaProviderID: String, Hashable {
    case plex
    case jellyfin
}

struct ConnectedServer: Equatable, Identifiable {
    let providerID: MediaProviderID
    let serverID: String
    let serverName: String
    let accountName: String
    let libraries: [LibraryShelf]

    var id: String {
        "\(providerID.rawValue):\(serverID)"
    }
}

struct LibraryShelf: Hashable, Identifiable {
    let id: String
    let title: String
    let reference: LibraryReference
    let items: [MediaItem]
}

struct LibraryReference: Hashable, Identifiable {
    let providerID: MediaProviderID
    let serverID: String
    let id: String
    let title: String
    let itemTitle: String
    let artworkStyle: MediaArtworkStyle
    let defaultItemKind: MediaItemKind
}

struct MediaArtworkSet: Hashable {
    let posterURL: URL?
    let landscapeURL: URL?
    let backdropURL: URL?

    func url(for style: MediaArtworkStyle) -> URL? {
        switch style {
        case .poster:
            posterURL ?? landscapeURL ?? backdropURL
        case .landscape:
            landscapeURL ?? backdropURL ?? posterURL
        }
    }
}

enum MediaItemKind: String, Hashable {
    case movie
    case series
    case season
    case episode
    case other

    var artworkStyle: MediaArtworkStyle {
        switch self {
        case .movie, .series, .season:
            return .poster
        case .episode, .other:
            return .landscape
        }
    }

    var isPlayable: Bool {
        switch self {
        case .movie, .episode, .other:
            return true
        case .series, .season:
            return false
        }
    }
}

struct MediaItem: Hashable, Identifiable {
    let providerID: MediaProviderID
    let serverID: String
    let id: String
    let title: String
    let kind: MediaItemKind
    let synopsis: String
    let addedAt: Int?
    let year: Int?
    let durationMilliseconds: Int?
    let contentRating: String?
    let isWatched: Bool
    let progress: Double?
    let resumeOffsetMilliseconds: Int?
    let artwork: MediaArtworkSet

    var playbackID: MediaPlaybackID? {
        guard kind.isPlayable else { return nil }
        return MediaPlaybackID(providerID: providerID, itemID: id)
    }

    var artworkURL: URL? {
        artwork.url(for: kind.artworkStyle)
    }

    var backdropURL: URL? {
        artwork.backdropURL ?? artwork.landscapeURL ?? artwork.posterURL
    }

    var runtimeText: String? {
        guard let durationMilliseconds else { return nil }

        let minutes = durationMilliseconds / 60_000
        guard minutes > 0 else { return nil }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours == 0 {
            return "\(minutes)m"
        }

        if remainingMinutes == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(remainingMinutes)m"
    }

    var subtitle: String? {
        [year.map(String.init), runtimeText]
            .compactMap { $0 }
            .joined(separator: " • ")
            .nilIfEmpty
    }

    var hasResume: Bool {
        (resumeOffsetMilliseconds ?? 0) > 0 && !isWatched
    }
}

struct MediaPlaybackID: Hashable {
    let providerID: MediaProviderID
    let itemID: String
}

struct MediaPlaybackOptions: Equatable {
    let audioOptions: [MediaPlaybackOption]
    let subtitleOptions: [MediaPlaybackOption]
    let selectedAudioID: String?
    let selectedSubtitleID: String?
}

struct MediaPlaybackOption: Identifiable, Hashable {
    let id: String
    let title: String
}

struct MediaPlaybackSelection: Equatable {
    let audioID: String?
    let subtitleID: String?
}

enum MediaPlaybackTimelineState: String {
    case stopped
    case buffering
    case playing
    case paused
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
