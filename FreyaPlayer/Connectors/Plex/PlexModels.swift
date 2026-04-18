import Foundation

struct PlexConnectionSummary {
    let serverID: String
    let serverName: String
    let serverURL: String
    let serverToken: String
    let accountName: String
    let libraries: [PlexLibrarySection]
}

struct PlexLibrary: Decodable, Identifiable {
    let key: String
    let title: String
    let type: String
    let agent: String?

    var id: String { key }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        type = try container.decode(String.self, forKey: .type)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        key = try container.decodeLossyString(forKey: .key)
    }

    private enum CodingKeys: String, CodingKey {
        case key
        case title
        case type
        case agent
    }
}

struct PlexLibrarySection: Identifiable {
    let id: String
    let title: String
    let type: String
    let agent: String?
    let items: [PlexMediaItem]
}

struct PlexLibraryContext: Hashable, Identifiable {
    let id: String
    let title: String
    let type: String
    let agent: String?

    var usesPosterArtwork: Bool {
        switch type {
        case "show":
            return true
        case "movie":
            return agent != "tv.plex.agents.none"
        default:
            return false
        }
    }

    var itemName: String {
        if type == "show" {
            return "show"
        }

        return usesPosterArtwork ? "movie" : "item"
    }
}

struct PlexMediaItem: Decodable, Identifiable, Hashable {
    let ratingKey: String
    let type: String?
    let title: String
    let summary: String?
    let addedAt: Int?
    let year: Int?
    let duration: Int?
    let viewOffset: Int?
    let contentRating: String?
    let viewCount: Int?
    let leafCount: Int?
    let viewedLeafCount: Int?
    let art: String?
    let thumb: String?
    let parentThumb: String?
    let grandparentThumb: String?

    var id: String { ratingKey }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ratingKey = try container.decodeLossyString(forKey: .ratingKey)
        type = try container.decodeLossyStringIfPresent(forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decodeLossyStringIfPresent(forKey: .summary)
        addedAt = try container.decodeLossyIntIfPresent(forKey: .addedAt)
        year = try container.decodeLossyIntIfPresent(forKey: .year)
        duration = try container.decodeLossyIntIfPresent(forKey: .duration)
        viewOffset = try container.decodeLossyIntIfPresent(forKey: .viewOffset)
        contentRating = try container.decodeLossyStringIfPresent(forKey: .contentRating)
        viewCount = try container.decodeLossyIntIfPresent(forKey: .viewCount)
        leafCount = try container.decodeLossyIntIfPresent(forKey: .leafCount)
        viewedLeafCount = try container.decodeLossyIntIfPresent(forKey: .viewedLeafCount)
        art = try container.decodeIfPresent(String.self, forKey: .art)
        thumb = try container.decodeIfPresent(String.self, forKey: .thumb)
        parentThumb = try container.decodeIfPresent(String.self, forKey: .parentThumb)
        grandparentThumb = try container.decodeIfPresent(String.self, forKey: .grandparentThumb)
    }

    var synopsis: String {
        summary.appSynopsis
    }

    var runtimeText: String? {
        guard let duration else { return nil }

        let minutes = duration / 60_000
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

    var isWatched: Bool {
        if let leafCount, leafCount > 0 {
            return (viewedLeafCount ?? 0) >= leafCount
        }

        return (viewCount ?? 0) > 0
    }

    var progress: Double? {
        if let leafCount, leafCount > 0 {
            let viewedLeafCount = viewedLeafCount ?? 0
            guard viewedLeafCount > 0, viewedLeafCount < leafCount else { return nil }
            return min(max(Double(viewedLeafCount) / Double(leafCount), 0), 1)
        }

        if let duration, duration > 0, let viewOffset, viewOffset > 0 {
            guard !isWatched else { return nil }
            return min(max(Double(viewOffset) / Double(duration), 0), 1)
        }

        return nil
    }

    private func imageURL(
        baseURL: String,
        token: String,
        path: String?,
        width: Int,
        height: Int
    ) -> URL? {
        guard let path,
              var components = URLComponents(string: "\(baseURL)/photo/:/transcode") else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "url", value: path),
            URLQueryItem(name: "width", value: String(width)),
            URLQueryItem(name: "height", value: String(height)),
            URLQueryItem(name: "minSize", value: "1"),
            URLQueryItem(name: "upscale", value: "1"),
            URLQueryItem(name: "X-Plex-Token", value: token)
        ]

        return components.url
    }

    private func posterImagePath(for kind: MediaItemKind) -> String? {
        switch kind {
        case .movie, .series, .season:
            return thumb ?? parentThumb ?? grandparentThumb
        case .episode, .other:
            return nil
        }
    }

    private func landscapeImagePath(for kind: MediaItemKind) -> String? {
        switch kind {
        case .movie, .series, .season:
            return nil
        case .episode:
            return thumb
        case .other:
            return art ?? thumb
        }
    }

    private func backdropImagePath(for kind: MediaItemKind) -> String? {
        switch kind {
        case .movie, .series, .season:
            return art
        case .episode:
            return thumb
        case .other:
            return art ?? thumb
        }
    }

    private enum CodingKeys: String, CodingKey {
        case ratingKey
        case type
        case title
        case summary
        case addedAt
        case year
        case duration
        case viewOffset
        case contentRating
        case viewCount
        case leafCount
        case viewedLeafCount
        case art
        case thumb
        case parentThumb
        case grandparentThumb
    }
}

extension PlexLibrarySection {
    var context: PlexLibraryContext {
        PlexLibraryContext(
            id: id,
            title: title,
            type: type,
            agent: agent
        )
    }

    var usesPosterArtwork: Bool {
        context.usesPosterArtwork
    }
}

struct PlexPin: Decodable {
    let id: Int
    let code: String
    let authToken: String?
    let expiresIn: Int?
}

extension PlexConnectionSummary {
    func connectedServer(providerID: MediaProviderID = .plex) -> ConnectedServer {
        ConnectedServer(
            providerID: providerID,
            serverID: serverID,
            serverName: serverName,
            accountName: accountName,
            libraries: libraries.map {
                $0.libraryShelf(
                    providerID: providerID,
                    serverID: serverID,
                    serverURL: serverURL,
                    serverToken: serverToken
                )
            }
        )
    }
}

extension PlexLibrarySection {
    func libraryShelf(
        providerID: MediaProviderID,
        serverID: String,
        serverURL: String,
        serverToken: String
    ) -> LibraryShelf {
        let reference = context.libraryReference(providerID: providerID, serverID: serverID)

        return LibraryShelf(
            id: id,
            title: title,
            reference: reference,
            items: items.map {
                $0.mediaItem(
                    providerID: providerID,
                    serverID: serverID,
                    serverURL: serverURL,
                    serverToken: serverToken,
                    fallbackKind: context.defaultItemKind
                )
            },
            isHidden: false
        )
    }
}

extension PlexLibraryContext {
    var defaultItemKind: MediaItemKind {
        switch type {
        case "show":
            return .series
        case "movie":
            return usesPosterArtwork ? .movie : .other
        default:
            return usesPosterArtwork ? .movie : .other
        }
    }

    func libraryReference(providerID: MediaProviderID, serverID: String) -> LibraryReference {
        LibraryReference(
            providerID: providerID,
            serverID: serverID,
            id: id,
            title: title,
            itemTitle: itemName,
            artworkStyle: usesPosterArtwork ? .poster : .landscape,
            defaultItemKind: defaultItemKind
        )
    }
}

extension PlexMediaItem {
    func mediaItem(
        providerID: MediaProviderID,
        serverID: String,
        serverURL: String,
        serverToken: String,
        fallbackKind: MediaItemKind
    ) -> MediaItem {
        let kind = resolvedKind(fallbackKind: fallbackKind)

        return MediaItem(
            providerID: providerID,
            serverID: serverID,
            id: ratingKey,
            title: title,
            kind: kind,
            synopsis: synopsis,
            addedAt: addedAt,
            year: year,
            durationMilliseconds: duration,
            contentRating: contentRating,
            isWatched: isWatched,
            progress: progress,
            resumeOffsetMilliseconds: !isWatched ? viewOffset : nil,
            artwork: MediaArtworkSet(
                posterURL: imageURL(
                    baseURL: serverURL,
                    token: serverToken,
                    path: posterImagePath(for: kind),
                    width: 480,
                    height: 720
                ),
                landscapeURL: imageURL(
                    baseURL: serverURL,
                    token: serverToken,
                    path: landscapeImagePath(for: kind),
                    width: 780,
                    height: 439
                ),
                backdropURL: imageURL(
                    baseURL: serverURL,
                    token: serverToken,
                    path: backdropImagePath(for: kind),
                    width: 1920,
                    height: 1080
                )
            )
        )
    }

    private func resolvedKind(fallbackKind: MediaItemKind) -> MediaItemKind {
        if fallbackKind == .other {
            return .other
        }

        return mediaItemKind ?? fallbackKind
    }

    private var mediaItemKind: MediaItemKind? {
        switch type {
        case "movie":
            return .movie
        case "show":
            return .series
        case "season":
            return .season
        case "episode":
            return .episode
        default:
            return nil
        }
    }
}
