import Foundation

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
        artwork.backdropURL ?? artwork.landscapeURL
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

    func settingWatchStatus(_ isWatched: Bool) -> MediaItem {
        MediaItem(
            providerID: providerID,
            serverID: serverID,
            id: id,
            title: title,
            kind: kind,
            synopsis: synopsis,
            addedAt: addedAt,
            year: year,
            durationMilliseconds: durationMilliseconds,
            contentRating: contentRating,
            isWatched: isWatched,
            progress: isWatched ? 1 : nil,
            resumeOffsetMilliseconds: nil,
            artwork: artwork
        )
    }
}

extension Optional where Wrapped == String {
    var appSynopsis: String {
        self?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "No description available."
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
