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

struct JellyfinProviderIds: Decodable, Hashable {
    let tmdb: String?
    let imdb: String?

    private enum CodingKeys: String, CodingKey {
        case tmdb = "Tmdb"
        case imdb = "Imdb"
    }
}

struct JellyfinItem: Decodable, Hashable, Identifiable {
    let id: String
    let name: String
    let type: String?
    let collectionType: String?
    let overview: String?
    let dateCreated: String?
    let premiereDate: String?
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
    let seriesThumbImageTag: String?
    let providerIds: JellyfinProviderIds?
    let mediaSources: [JellyfinMediaSource]?

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case collectionType = "CollectionType"
        case overview = "Overview"
        case dateCreated = "DateCreated"
        case premiereDate = "PremiereDate"
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
        case seriesThumbImageTag = "SeriesThumbImageTag"
        case providerIds = "ProviderIds"
        case mediaSources = "MediaSources"
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

struct JellyfinMediaSource: Decodable, Hashable {
    let id: String?
    let name: String?
    let path: String?
    let size: Int64?
    let container: String?
    let bitrate: Int?
    let runTimeTicks: Int64?
    let videoType: String?
    let supportsDirectPlay: Bool
    let supportsDirectStream: Bool
    let supportsTranscoding: Bool
    let transcodingURL: String?
    let mediaStreams: [JellyfinMediaStream]?
    let defaultAudioStreamIndex: Int?
    let defaultSubtitleStreamIndex: Int?

    var directPlayContainer: String? {
        ["mp4", "m4v", "mov"].first { container?.lowercased().split(separator: ",").contains(Substring($0)) == true }
    }

    var isDirectPlayable: Bool {
        guard directPlayContainer != nil,
              let video = mediaStreams?.first(where: { $0.type == "Video" }),
              ["h264", "hevc", "h265"].contains(video.codec?.lowercased() ?? ""),
              let audio = mediaStreams?.first(where: {
                  $0.type == "Audio" && $0.index == defaultAudioStreamIndex
              }) ?? mediaStreams?.first(where: { $0.type == "Audio" }) else { return false }
        return ["aac", "mp3"].contains(audio.codec?.lowercased() ?? "")
    }

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case path = "Path"
        case size = "Size"
        case container = "Container"
        case bitrate = "Bitrate"
        case runTimeTicks = "RunTimeTicks"
        case videoType = "VideoType"
        case supportsDirectPlay = "SupportsDirectPlay"
        case supportsDirectStream = "SupportsDirectStream"
        case supportsTranscoding = "SupportsTranscoding"
        case transcodingURL = "TranscodingUrl"
        case mediaStreams = "MediaStreams"
        case defaultAudioStreamIndex = "DefaultAudioStreamIndex"
        case defaultSubtitleStreamIndex = "DefaultSubtitleStreamIndex"
    }
}

struct JellyfinMediaStream: Decodable, Hashable {
    let index: Int
    let type: String
    let codec: String?
    let codecTag: String?
    let displayTitle: String?
    let language: String?
    let isDefault: Bool
    let isForced: Bool?
    let isExternal: Bool?
    let channels: Int?
    let channelLayout: String?
    let bitrate: Int?
    let bitDepth: Int?
    let sampleRate: Int?
    let width: Int?
    let height: Int?
    let averageFrameRate: Double?
    let realFrameRate: Double?
    let videoRange: String?
    let videoRangeType: String?
    let profile: String?
    let level: Int?
    let pixelFormat: String?
    let aspectRatio: String?
    let isInterlaced: Bool?

    private enum CodingKeys: String, CodingKey {
        case index = "Index"
        case type = "Type"
        case codec = "Codec"
        case codecTag = "CodecTag"
        case displayTitle = "DisplayTitle"
        case language = "Language"
        case isDefault = "IsDefault"
        case isForced = "IsForced"
        case isExternal = "IsExternal"
        case channels = "Channels"
        case channelLayout = "ChannelLayout"
        case bitrate = "BitRate"
        case bitDepth = "BitDepth"
        case sampleRate = "SampleRate"
        case width = "Width"
        case height = "Height"
        case averageFrameRate = "AverageFrameRate"
        case realFrameRate = "RealFrameRate"
        case videoRange = "VideoRange"
        case videoRangeType = "VideoRangeType"
        case profile = "Profile"
        case level = "Level"
        case pixelFormat = "PixelFormat"
        case aspectRatio = "AspectRatio"
        case isInterlaced = "IsInterlaced"
    }
}

extension JellyfinMediaSource {
    func playbackOptions(requiresTranscodedAudio: Bool) -> MediaPlaybackOptions {
        let streams = mediaStreams ?? []
        let video = streams.first(where: { $0.type == "Video" })
        let videoHeight = video?.height
        let transcodesBoth = !supportsDirectPlay && !supportsDirectStream
        let canDirectStreamVideo = ["h264", "avc", "avc1"].contains(video?.codec?.lowercased() ?? "")
        let transcodesAudio = requiresTranscodedAudio || transcodesBoth
        let audioOptions = streams
            .filter { $0.type == "Audio" }
            .map { stream in
                let canDirectStream = ["aac", "mp3"].contains(stream.codec?.lowercased() ?? "")
                return MediaPlaybackOption(
                    id: String(stream.index),
                    title: stream.displayTitle ?? stream.language ?? "Audio \(stream.index)",
                    transcodingTitle: transcodesAudio || !canDirectStream ? "AAC" : nil,
                    sourceFormat: MediaTranscoding.audio(
                        codec: stream.codec,
                        channels: stream.channels,
                        channelLayout: stream.channelLayout
                    )
                )
            }
        let selectedAudioID = defaultAudioStreamIndex.map(String.init) ?? audioOptions.first?.id
        let subtitleOptions = streams
            .filter { $0.type == "Subtitle" && MediaTranscoding.canStreamSubtitle(codec: $0.codec) }
            .map { stream in
                MediaPlaybackOption(
                    id: String(stream.index),
                    title: stream.displayTitle ?? stream.language ?? "Subtitle \(stream.index)",
                    transcodingTitle: "WebVTT",
                    sourceFormat: MediaTranscoding.subtitles(
                        codec: stream.codec,
                        isExternal: stream.isExternal == true
                    )
                )
            }
        let selectedSubtitleID = defaultSubtitleStreamIndex.map(String.init).flatMap { subtitleID in
            subtitleOptions.contains(where: { $0.id == subtitleID }) ? subtitleID : nil
        }
        let selectedAudioStream = streams.first { stream in
            stream.type == "Audio" && String(stream.index) == selectedAudioID
        }
        let defaultAudioTranscoding = selectedAudioID.flatMap { audioID in
            audioOptions.first(where: { $0.id == audioID })?.transcodingTitle
        }

        return MediaPlaybackOptions(
            videoHeight: videoHeight,
            qualityOptions: MediaPlaybackQuality.transcodingOptions(forVideoHeight: videoHeight),
            audioOptions: audioOptions,
            subtitleOptions: subtitleOptions,
            selectedAudioID: selectedAudioID,
            selectedSubtitleID: selectedSubtitleID,
            defaultVideoTranscoding: transcodesBoth ? "H.264" : nil,
            defaultAudioTranscoding: defaultAudioTranscoding,
            streamingVideoTranscoding: canDirectStreamVideo ? nil : "H.264",
            sourceContainer: MediaTranscoding.container(container),
            sourceVideo: MediaTranscoding.video(
                codec: video?.codec,
                height: video?.height,
                dynamicRange: video?.videoRangeType ?? video?.videoRange
            ),
            sourceAudio: MediaTranscoding.audio(
                codec: selectedAudioStream?.codec,
                channels: selectedAudioStream?.channels,
                channelLayout: selectedAudioStream?.channelLayout
            ),
            defaultContainerTranscoding: !supportsDirectPlay
        )
    }

    func playbackFormats(selection: MediaPlaybackSelection?) -> MediaPlaybackFormats {
        let video = mediaStreams?.first(where: { $0.type == "Video" })
        let audio = selectedAudioStream(selection: selection)
        let subtitle = selectedSubtitleStream(selection: selection)
        return MediaPlaybackFormats(
            container: MediaTranscoding.container(directPlayContainer ?? container),
            video: MediaTranscoding.video(
                codec: video?.codec,
                height: video?.height,
                dynamicRange: video?.videoRangeType ?? video?.videoRange
            ),
            audio: MediaTranscoding.audio(
                codec: audio?.codec,
                channels: audio?.channels,
                channelLayout: audio?.channelLayout
            ),
            subtitles: MediaTranscoding.subtitles(
                codec: subtitle?.codec,
                isExternal: subtitle?.isExternal == true
            )
        )
    }

    var canCopyVideo: Bool {
        let video = mediaStreams?.first(where: { $0.type == "Video" })
        return ["avc", "avc1", "h264"].contains(video?.codec?.lowercased() ?? "")
    }

    func canCopyAudio(selection: MediaPlaybackSelection?) -> Bool {
        let audio = selectedAudioStream(selection: selection)
        return ["aac", "mp3"].contains(audio?.codec?.lowercased() ?? "")
    }

    private func selectedAudioStream(selection: MediaPlaybackSelection?) -> JellyfinMediaStream? {
        let index = selection?.audioID.flatMap(Int.init) ?? defaultAudioStreamIndex
        return mediaStreams?.first { $0.type == "Audio" && $0.index == index }
            ?? mediaStreams?.first(where: { $0.type == "Audio" })
    }

    private func selectedSubtitleStream(selection: MediaPlaybackSelection?) -> JellyfinMediaStream? {
        guard let index = selection?.subtitleID.flatMap(Int.init) else { return nil }
        return mediaStreams?.first { $0.type == "Subtitle" && $0.index == index }
    }
}

extension JellyfinConnectionSummary {
    func connectedServer(providerID: MediaProviderID = .jellyfin) -> ConnectedServer {
        ConnectedServer(
            providerID: providerID,
            serverID: serverID,
            serverName: serverName,
            serverURL: serverURL,
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
            releasedAt: releaseTimestamp,
            year: productionYear,
            durationMilliseconds: runTimeTicks.map { Int($0 / 10_000) },
            contentRating: officialRating,
            tmdbID: providerIds?.tmdb,
            isWatched: isWatched,
            progress: progress,
            resumeOffsetMilliseconds: isWatched ? nil : resumeOffsetMilliseconds,
            artwork: MediaArtworkSet(
                posterURL: posterImageURL(for: kind, baseURL: serverURL, accessToken: accessToken),
                thumbnailURL: thumbnailImageURL(baseURL: serverURL, accessToken: accessToken),
                landscapeURL: landscapeImageURL(for: kind, baseURL: serverURL, accessToken: accessToken),
                backdropURL: backdropURL(baseURL: serverURL, accessToken: accessToken)
            ),
            detailSections: mediaDetailSections
        )
    }

    private var mediaDetailSections: [MediaItemDetailSection] {
        var sections: [MediaItemDetailSection] = []
        if let imdb = providerIds?.imdb {
            sections.append(.init(title: "Identifiers", rows: [.init(label: "IMDb ID", value: imdb)]))
        }

        for (sourceIndex, source) in (mediaSources ?? []).enumerated() {
            let sourceRows: [MediaItemDetailSection.Row?] = [
                source.name.map { .init(label: "Name", value: $0) },
                source.path.map { .init(label: "File Name", value: URL(fileURLWithPath: $0).lastPathComponent) },
                source.path.map { .init(label: "Path", value: $0) },
                source.size.map { .init(label: "Size", value: ByteCountFormatter.string(fromByteCount: $0, countStyle: .file)) },
                source.container.map { .init(label: "Container", value: $0.uppercased()) },
                source.bitrate.map { .init(label: "Bitrate", value: "\($0 / 1_000) kbps") },
                source.videoType.map { .init(label: "Video Type", value: $0) },
                source.runTimeTicks.map { .init(label: "Duration", value: "\($0 / 10_000) ms") }
            ]
            let prefix = "Media Source \(sourceIndex + 1)"
            sections.append(.init(title: prefix, rows: sourceRows.compactMap { $0 }))

            for (streamIndex, stream) in (source.mediaStreams ?? []).enumerated() {
                let rows: [MediaItemDetailSection.Row?] = [
                    stream.codec.map { .init(label: "Codec", value: $0.uppercased()) },
                    stream.codecTag.map { .init(label: "Codec Tag", value: $0) },
                    stream.displayTitle.map { .init(label: "Title", value: $0) },
                    stream.language.map { .init(label: "Language", value: $0) },
                    resolution(width: stream.width, height: stream.height).map { .init(label: "Dimensions", value: $0) },
                    stream.bitrate.map { .init(label: "Bitrate", value: "\($0 / 1_000) kbps") },
                    stream.channels.map { .init(label: "Channels", value: String($0)) },
                    stream.channelLayout.map { .init(label: "Channel Layout", value: $0) },
                    stream.sampleRate.map { .init(label: "Sample Rate", value: "\($0) Hz") },
                    stream.bitDepth.map { .init(label: "Bit Depth", value: "\($0)-bit") },
                    stream.averageFrameRate.map { .init(label: "Average Frame Rate", value: String($0)) },
                    stream.realFrameRate.map { .init(label: "Real Frame Rate", value: String($0)) },
                    stream.aspectRatio.map { .init(label: "Aspect Ratio", value: $0) },
                    stream.profile.map { .init(label: "Profile", value: $0) },
                    stream.level.map { .init(label: "Level", value: String($0)) },
                    stream.pixelFormat.map { .init(label: "Pixel Format", value: $0) },
                    stream.videoRange.map { .init(label: "Video Range", value: $0) },
                    stream.videoRangeType.map { .init(label: "Video Range Type", value: $0) },
                    stream.isInterlaced.map { .init(label: "Interlaced", value: $0 ? "Yes" : "No") },
                    .init(label: "Default", value: stream.isDefault ? "Yes" : "No"),
                    stream.isForced.map { .init(label: "Forced", value: $0 ? "Yes" : "No") },
                    stream.isExternal.map { .init(label: "External", value: $0 ? "Yes" : "No") }
                ]
                sections.append(.init(
                    title: "\(prefix) · \(stream.type) \(streamIndex + 1)",
                    rows: rows.compactMap { $0 }
                ))
            }
        }

        return sections.filter { !$0.rows.isEmpty }
    }

    private func resolution(width: Int?, height: Int?) -> String? {
        guard let width, let height else { return nil }
        return "\(width) × \(height)"
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

    private var releaseTimestamp: Int? {
        guard let premiereDate else { return nil }
        return JellyfinDateParser.parse(premiereDate).map { Int($0.timeIntervalSince1970) }
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

    private var thumbImageItemID: String? {
        if imageTags?["Thumb"] != nil {
            return id
        }

        if let parentThumbItemId, parentThumbImageTag != nil {
            return parentThumbItemId
        }

        if let seriesId, seriesThumbImageTag != nil {
            return seriesId
        }

        return nil
    }

    private var thumbImageTag: String? {
        imageTags?["Thumb"] ?? parentThumbImageTag ?? seriesThumbImageTag
    }

    private func posterImageURL(
        for kind: MediaItemKind,
        baseURL: String,
        accessToken: String
    ) -> URL? {
        guard kind == .movie || kind == .series || kind == .season || kind == .other else {
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

        return nil
    }

    private func thumbnailImageURL(
        baseURL: String,
        accessToken: String
    ) -> URL? {
        guard let thumbImageItemID, let tag = thumbImageTag else {
            return nil
        }

        return imageURL(
            type: "Thumb",
            itemID: thumbImageItemID,
            tag: tag,
            baseURL: baseURL,
            accessToken: accessToken,
            maxWidth: 780,
            maxHeight: 439
        )
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
            return nil
        }
    }

    private func backdropURL(
        baseURL: String,
        accessToken: String
    ) -> URL? {
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
