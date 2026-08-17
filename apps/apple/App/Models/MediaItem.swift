import Foundation

enum MediaItemKind: String, Hashable, Codable {
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

struct MediaItem: Hashable, Identifiable, Codable {
    let providerID: MediaProviderID
    let serverID: String
    let id: String
    let title: String
    let kind: MediaItemKind
    let synopsis: String
    let addedAt: Int?
    let releasedAt: Int?
    let year: Int?
    let durationMilliseconds: Int?
    let contentRating: String?
    let tmdbID: String?
    let isWatched: Bool
    let progress: Double?
    let resumeOffsetMilliseconds: Int?
    let artwork: MediaArtworkSet
    let detailSections: [MediaItemDetailSection]?

    var playbackID: MediaPlaybackID? {
        guard kind.isPlayable else { return nil }
        return MediaPlaybackID(providerID: providerID, itemID: id)
    }

    var artworkURL: URL? {
        artwork.url(for: kind.artworkStyle)
    }

    var backdropURL: URL? {
        artwork.backdropURL ?? artwork.landscapeURL ?? artwork.thumbnailURL
    }

    var runtimeText: String? {
        guard let durationMilliseconds else { return nil }

        let minutes = durationMilliseconds / 60_000
        guard minutes > 0 else { return "<1m" }

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

    func libraryTileSubtitle(showsAddedAt: Bool) -> String? {
        guard let runtimeText else { return nil }
        guard showsAddedAt, let addedAtFormatted else { return runtimeText }
        return "\(runtimeText) • \(addedAtFormatted)"
    }

    var addedAtFormatted: String? {
        guard let addedAt else { return nil }
        return Self.dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(addedAt)))
    }

    var releasedAtFormatted: String? {
        guard let releasedAt else { return nil }
        return Self.dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(releasedAt)))
    }

    var hasResume: Bool {
        (resumeOffsetMilliseconds ?? 0) > 0 && !isWatched
    }

    var playButtonTitle: String {
        guard hasResume, let resumeOffsetMilliseconds else { return "Play" }

        let totalSeconds = resumeOffsetMilliseconds / 1_000
        let hours = totalSeconds / 3_600
        let minutes = totalSeconds % 3_600 / 60
        let seconds = totalSeconds % 60
        let timestamp = hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
        return "Resume at \(timestamp)"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    func settingWatchStatus(_ isWatched: Bool) -> MediaItem {
        applyingWatchStats(isWatched: isWatched, progress: isWatched ? 1 : nil, resumeOffsetMilliseconds: nil)
    }

    func applyingWatchStats(
        isWatched: Bool,
        progress: Double?,
        resumeOffsetMilliseconds: Int?
    ) -> MediaItem {
        MediaItem(
            providerID: providerID,
            serverID: serverID,
            id: id,
            title: title,
            kind: kind,
            synopsis: synopsis,
            addedAt: addedAt,
            releasedAt: releasedAt,
            year: year,
            durationMilliseconds: durationMilliseconds,
            contentRating: contentRating,
            tmdbID: tmdbID,
            isWatched: isWatched,
            progress: progress,
            resumeOffsetMilliseconds: resumeOffsetMilliseconds,
            artwork: artwork,
            detailSections: detailSections
        )
    }

    func withAddedAt(_ addedAt: Int?) -> MediaItem {
        MediaItem(
            providerID: providerID,
            serverID: serverID,
            id: id,
            title: title,
            kind: kind,
            synopsis: synopsis,
            addedAt: addedAt,
            releasedAt: releasedAt,
            year: year,
            durationMilliseconds: durationMilliseconds,
            contentRating: contentRating,
            tmdbID: tmdbID,
            isWatched: isWatched,
            progress: progress,
            resumeOffsetMilliseconds: resumeOffsetMilliseconds,
            artwork: artwork,
            detailSections: detailSections
        )
    }

    func withReleasedAt(_ releasedAt: Int?) -> MediaItem {
        MediaItem(
            providerID: providerID,
            serverID: serverID,
            id: id,
            title: title,
            kind: kind,
            synopsis: synopsis,
            addedAt: addedAt,
            releasedAt: releasedAt,
            year: year,
            durationMilliseconds: durationMilliseconds,
            contentRating: contentRating,
            tmdbID: tmdbID,
            isWatched: isWatched,
            progress: progress,
            resumeOffsetMilliseconds: resumeOffsetMilliseconds,
            artwork: artwork,
            detailSections: detailSections
        )
    }

    static func derivedWatchStats(fromLeaves leaves: [MediaItem]) -> (isWatched: Bool, progress: Double?) {
        guard !leaves.isEmpty else { return (false, nil) }

        let watched = leaves.filter(\.isWatched).count
        let progress = leaves.reduce(0.0) { total, item in
            total + (item.isWatched ? 1 : ((item.progress ?? 0) > 0 || (item.resumeOffsetMilliseconds ?? 0) > 0 ? 0.5 : 0))
        }
        if progress == 0 {
            return (false, nil)
        }
        if watched == leaves.count {
            return (true, nil)
        }
        return (false, progress / Double(leaves.count))
    }

    func applyingLatestEpisodeAddedAt(from episodes: [MediaItem]) -> MediaItem {
        guard kind == .series else { return self }
        let latestAddedAt = episodes
            .filter { $0.kind == .episode }
            .compactMap(\.addedAt)
            .max()
        guard let latestAddedAt else { return self }
        return withAddedAt(latestAddedAt)
    }

    func preservingNewerSeriesAddedAt(from cachedItem: MediaItem?) -> MediaItem {
        guard kind == .series, let cachedAddedAt = cachedItem?.addedAt else { return self }
        guard cachedAddedAt > (addedAt ?? .min) else { return self }
        return withAddedAt(cachedAddedAt)
    }
}

struct MediaItemDetailSection: Hashable, Codable, Identifiable {
    let title: String
    let rows: [Row]

    var id: String { title }

    struct Row: Hashable, Codable, Identifiable {
        let label: String
        let value: String

        var id: String { "\(label):\(value)" }
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
