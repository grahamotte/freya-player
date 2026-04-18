import Foundation

struct JellyfinConnectionSummary {
    let serverID: String
    let serverName: String
    let serverURL: String
    let accessToken: String
    let userID: String
    let userName: String
    let sessionID: String?
    let libraries: [JellyfinLibrary]
}

struct JellyfinLibrary {
    let id: String
    let title: String
    let collectionType: String?
    let items: [JellyfinItem]
}

struct JellyfinAuthenticationResult: Decodable {
    let user: JellyfinUser
    let sessionInfo: JellyfinSessionInfo?
    let accessToken: String
    let serverId: String?

    private enum CodingKeys: String, CodingKey {
        case user = "User"
        case sessionInfo = "SessionInfo"
        case accessToken = "AccessToken"
        case serverId = "ServerId"
    }
}

struct JellyfinUser: Decodable {
    let id: String
    let name: String?

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
    }
}

struct JellyfinSessionInfo: Decodable {
    let id: String?

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
    }
}

struct JellyfinPublicSystemInfo: Decodable {
    let id: String?
    let serverName: String?

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case serverName = "ServerName"
    }
}

struct JellyfinItemsResponse: Decodable {
    let items: [JellyfinItem]
    let totalRecordCount: Int

    private enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
    }
}

struct JellyfinItem: Decodable, Hashable, Identifiable {
    let id: String
    let name: String
    let type: String?
    let collectionType: String?
    let overview: String?
    let dateCreated: String?
    let productionYear: Int?
    let runTimeTicks: Int64?
    let officialRating: String?
    let userData: JellyfinUserData?
    let imageTags: [String: String]?
    let backdropImageTags: [String]?
    let parentBackdropItemId: String?
    let parentBackdropImageTags: [String]?
    let parentThumbItemId: String?
    let parentThumbImageTag: String?
    let parentPrimaryImageItemId: String?
    let parentPrimaryImageTag: String?
    let seriesId: String?
    let seriesPrimaryImageTag: String?

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case collectionType = "CollectionType"
        case overview = "Overview"
        case dateCreated = "DateCreated"
        case productionYear = "ProductionYear"
        case runTimeTicks = "RunTimeTicks"
        case officialRating = "OfficialRating"
        case userData = "UserData"
        case imageTags = "ImageTags"
        case backdropImageTags = "BackdropImageTags"
        case parentBackdropItemId = "ParentBackdropItemId"
        case parentBackdropImageTags = "ParentBackdropImageTags"
        case parentThumbItemId = "ParentThumbItemId"
        case parentThumbImageTag = "ParentThumbImageTag"
        case parentPrimaryImageItemId = "ParentPrimaryImageItemId"
        case parentPrimaryImageTag = "ParentPrimaryImageTag"
        case seriesId = "SeriesId"
        case seriesPrimaryImageTag = "SeriesPrimaryImageTag"
    }
}

struct JellyfinUserData: Decodable, Hashable {
    let playedPercentage: Double?
    let unplayedItemCount: Int?
    let playbackPositionTicks: Int64?
    let playCount: Int?
    let played: Bool?

    private enum CodingKeys: String, CodingKey {
        case playedPercentage = "PlayedPercentage"
        case unplayedItemCount = "UnplayedItemCount"
        case playbackPositionTicks = "PlaybackPositionTicks"
        case playCount = "PlayCount"
        case played = "Played"
    }
}

struct JellyfinPlaybackInfoResponse: Decodable {
    let playSessionId: String?
    let mediaSources: [JellyfinMediaSource]

    private enum CodingKeys: String, CodingKey {
        case playSessionId = "PlaySessionId"
        case mediaSources = "MediaSources"
    }
}

struct JellyfinMediaSource: Decodable {
    let id: String?
    let container: String?
    let supportsDirectPlay: Bool
    let supportsDirectStream: Bool
    let supportsTranscoding: Bool
    let transcodingURL: String?
    let mediaStreams: [JellyfinMediaStream]?
    let defaultAudioStreamIndex: Int?
    let defaultSubtitleStreamIndex: Int?

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case container = "Container"
        case supportsDirectPlay = "SupportsDirectPlay"
        case supportsDirectStream = "SupportsDirectStream"
        case supportsTranscoding = "SupportsTranscoding"
        case transcodingURL = "TranscodingUrl"
        case mediaStreams = "MediaStreams"
        case defaultAudioStreamIndex = "DefaultAudioStreamIndex"
        case defaultSubtitleStreamIndex = "DefaultSubtitleStreamIndex"
    }
}

struct JellyfinMediaStream: Decodable {
    let index: Int
    let type: String
    let displayTitle: String?
    let language: String?
    let isDefault: Bool

    private enum CodingKeys: String, CodingKey {
        case index = "Index"
        case type = "Type"
        case displayTitle = "DisplayTitle"
        case language = "Language"
        case isDefault = "IsDefault"
    }
}

extension JellyfinConnectionSummary {
    func connectedServer(providerID: MediaProviderID = .jellyfin) -> ConnectedServer {
        ConnectedServer(
            providerID: providerID,
            serverID: serverID,
            serverName: serverName,
            accountName: userName,
            libraries: libraries.map {
                $0.libraryShelf(
                    providerID: providerID,
                    serverID: serverID,
                    serverURL: serverURL,
                    accessToken: accessToken
                )
            }
        )
    }
}

extension JellyfinLibrary {
    func libraryShelf(
        providerID: MediaProviderID,
        serverID: String,
        serverURL: String,
        accessToken: String
    ) -> LibraryShelf {
        let reference = libraryReference(providerID: providerID, serverID: serverID)

        return LibraryShelf(
            id: id,
            title: title,
            reference: reference,
            items: items.map {
                $0.mediaItem(
                    providerID: providerID,
                    serverID: serverID,
                    serverURL: serverURL,
                    accessToken: accessToken,
                    fallbackKind: reference.defaultItemKind
                )
            },
            isHidden: false
        )
    }

    func libraryReference(providerID: MediaProviderID, serverID: String) -> LibraryReference {
        let (itemTitle, artworkStyle, defaultItemKind): (String, MediaArtworkStyle, MediaItemKind) = switch collectionType {
        case "movies":
            ("movie", .poster, .movie)
        case "tvshows":
            ("show", .poster, .series)
        default:
            ("item", .landscape, .other)
        }

        return LibraryReference(
            providerID: providerID,
            serverID: serverID,
            id: id,
            title: title,
            itemTitle: itemTitle,
            artworkStyle: artworkStyle,
            defaultItemKind: defaultItemKind
        )
    }
}

extension JellyfinItem {
    func mediaItem(
        providerID: MediaProviderID,
        serverID: String,
        serverURL: String,
        accessToken: String,
        fallbackKind: MediaItemKind
    ) -> MediaItem {
        let userData = userData
        let kind = resolvedKind(fallbackKind: fallbackKind)
        let isWatched = userData?.played == true || (userData?.playCount ?? 0) > 0
        let resumeOffsetMilliseconds = playbackPositionTicks.flatMap { ticks in
            let milliseconds = Int(ticks / 10_000)
            return milliseconds > 0 ? milliseconds : nil
        }

        return MediaItem(
            providerID: providerID,
            serverID: serverID,
            id: id,
            title: name,
            kind: kind,
            synopsis: synopsis,
            addedAt: addedAtTimestamp,
            year: productionYear,
            durationMilliseconds: runTimeTicks.map { Int($0 / 10_000) },
            contentRating: officialRating,
            isWatched: isWatched,
            progress: progress,
            resumeOffsetMilliseconds: isWatched ? nil : resumeOffsetMilliseconds,
            artwork: MediaArtworkSet(
                posterURL: posterImageURL(for: kind, baseURL: serverURL, accessToken: accessToken),
                landscapeURL: landscapeImageURL(for: kind, baseURL: serverURL, accessToken: accessToken),
                backdropURL: backdropURL(for: kind, baseURL: serverURL, accessToken: accessToken)
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
        case "Movie":
            return .movie
        case "Series":
            return .series
        case "Season":
            return .season
        case "Episode":
            return .episode
        default:
            return nil
        }
    }

    private var synopsis: String {
        overview.appSynopsis
    }

    private var addedAtTimestamp: Int? {
        guard let dateCreated else { return nil }
        return JellyfinDateParser.parse(dateCreated).map { Int($0.timeIntervalSince1970) }
    }

    private var playbackPositionTicks: Int64? {
        userData?.playbackPositionTicks
    }

    private var progress: Double? {
        if let playedPercentage = userData?.playedPercentage, playedPercentage > 0, playedPercentage < 100 {
            return min(max(playedPercentage / 100, 0), 1)
        }

        if let runTimeTicks, runTimeTicks > 0, let playbackPositionTicks, playbackPositionTicks > 0, userData?.played != true {
            return min(max(Double(playbackPositionTicks) / Double(runTimeTicks), 0), 1)
        }

        return nil
    }

    private var primaryImageItemID: String {
        if imageTags?["Primary"] != nil {
            return id
        }

        if let parentPrimaryImageItemId, parentPrimaryImageTag != nil {
            return parentPrimaryImageItemId
        }

        if let seriesId, seriesPrimaryImageTag != nil {
            return seriesId
        }

        return id
    }

    private var primaryImageTag: String? {
        imageTags?["Primary"] ?? parentPrimaryImageTag ?? seriesPrimaryImageTag
    }

    private var hasPrimaryPosterCandidate: Bool {
        imageTags?["Primary"] != nil || parentPrimaryImageTag != nil || seriesPrimaryImageTag != nil
    }

    private func posterImageURL(
        for kind: MediaItemKind,
        baseURL: String,
        accessToken: String
    ) -> URL? {
        guard kind == .movie || kind == .series || kind == .season else {
            return nil
        }

        if hasPrimaryPosterCandidate {
            return imageURL(
                type: "Primary",
                itemID: primaryImageItemID,
                tag: primaryImageTag,
                baseURL: baseURL,
                accessToken: accessToken,
                maxWidth: 480,
                maxHeight: 720
            )
        }

        if let tag = imageTags?["Thumb"] {
            return imageURL(
                type: "Thumb",
                itemID: id,
                tag: tag,
                baseURL: baseURL,
                accessToken: accessToken,
                maxWidth: 480,
                maxHeight: 720
            )
        }

        return nil
    }

    private func landscapeImageURL(
        for kind: MediaItemKind,
        baseURL: String,
        accessToken: String
    ) -> URL? {
        switch kind {
        case .movie, .series, .season:
            return nil
        case .episode:
            if let tag = imageTags?["Thumb"] {
                return imageURL(
                    type: "Thumb",
                    itemID: id,
                    tag: tag,
                    baseURL: baseURL,
                    accessToken: accessToken,
                    maxWidth: 780,
                    maxHeight: 439
                )
            }

            if let tag = imageTags?["Primary"] {
                return imageURL(
                    type: "Primary",
                    itemID: id,
                    tag: tag,
                    baseURL: baseURL,
                    accessToken: accessToken,
                    maxWidth: 780,
                    maxHeight: 439
                )
            }

            return nil
        case .other:
            if let tag = backdropImageTags?.first {
                return imageURL(
                    type: "Backdrop",
                    itemID: id,
                    tag: tag,
                    index: 0,
                    baseURL: baseURL,
                    accessToken: accessToken,
                    maxWidth: 780,
                    maxHeight: 439
                )
            }

            if let tag = imageTags?["Thumb"] {
                return imageURL(
                    type: "Thumb",
                    itemID: id,
                    tag: tag,
                    baseURL: baseURL,
                    accessToken: accessToken,
                    maxWidth: 780,
                    maxHeight: 439
                )
            }

            return nil
        }
    }

    private func backdropURL(
        for kind: MediaItemKind,
        baseURL: String,
        accessToken: String
    ) -> URL? {
        switch kind {
        case .movie, .series, .season:
            if let tag = backdropImageTags?.first {
                return imageURL(
                    type: "Backdrop",
                    itemID: id,
                    tag: tag,
                    index: 0,
                    baseURL: baseURL,
                    accessToken: accessToken,
                    maxWidth: 1920,
                    maxHeight: 1080
                )
            }

            if let parentBackdropItemId, let tag = parentBackdropImageTags?.first {
                return imageURL(
                    type: "Backdrop",
                    itemID: parentBackdropItemId,
                    tag: tag,
                    index: 0,
                    baseURL: baseURL,
                    accessToken: accessToken,
                    maxWidth: 1920,
                    maxHeight: 1080
                )
            }

            return nil
        case .episode, .other:
            return landscapeImageURL(for: kind, baseURL: baseURL, accessToken: accessToken)
        }
    }

    private func imageURL(
        type: String,
        itemID: String,
        tag: String?,
        index: Int? = nil,
        baseURL: String,
        accessToken: String,
        maxWidth: Int,
        maxHeight: Int
    ) -> URL? {
        guard var components = URLComponents(string: "\(baseURL)/Items/\(itemID)/Images/\(type)") else {
            return nil
        }

        if let index {
            components.path += "/\(index)"
        }

        components.queryItems = [
            tag.map { URLQueryItem(name: "tag", value: $0) },
            URLQueryItem(name: "maxWidth", value: String(maxWidth)),
            URLQueryItem(name: "maxHeight", value: String(maxHeight)),
            URLQueryItem(name: "quality", value: "90"),
            URLQueryItem(name: "api_key", value: accessToken)
        ]
        .compactMap { $0 }

        return components.url
    }
}

enum JellyfinDateParser {
    private static let formatters: [ISO8601DateFormatter] = {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        return [fractional, plain]
    }()

    static func parse(_ value: String) -> Date? {
        for formatter in formatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }
}
