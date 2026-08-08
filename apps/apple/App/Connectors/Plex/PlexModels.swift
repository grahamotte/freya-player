import Foundation

struct PlexConnectionSummary {
    let serverID: String
    let serverName: String
    let serverURL: String
    let serverToken: String
    let accountName: String
    let isLocal: Bool
    let libraries: [PlexLibrarySection]

    var automaticVideoBitrateLimit: Int? { isLocal ? nil : 12_000 }
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

enum PlexDateParser {
    nonisolated static func parse(_ value: String) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
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

struct PlexGuid: Decodable, Hashable {
    let id: String
}

struct PlexMediaItem: Decodable, Identifiable, Hashable {
    let ratingKey: String
    let type: String?
    let title: String
    let summary: String?
    let addedAt: Int?
    let originallyAvailableAt: String?
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
    let guid: [PlexGuid]?
    let media: [PlexMediaFile]?

    var id: String { ratingKey }

    var tmdbID: String? {
        guid?.first { $0.id.hasPrefix("tmdb://") }?.id.replacingOccurrences(of: "tmdb://", with: "")
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ratingKey = try container.decodeLossyString(forKey: .ratingKey)
        type = try container.decodeLossyStringIfPresent(forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decodeLossyStringIfPresent(forKey: .summary)
        addedAt = try container.decodeLossyIntIfPresent(forKey: .addedAt)
        originallyAvailableAt = try container.decodeLossyStringIfPresent(forKey: .originallyAvailableAt)
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
        guid = try container.decodeIfPresent([PlexGuid].self, forKey: .guid)
        media = try container.decodeIfPresent([PlexMediaFile].self, forKey: .media)
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
        case .episode:
            return nil
        case .other:
            return thumb
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
        case originallyAvailableAt
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
        case guid = "Guid"
        case media = "Media"
    }
}

struct PlexMediaFile: Decodable, Hashable {
    let container: String?
    let videoCodec: String?
    let audioCodec: String?
    let videoResolution: String?
    let width: Int?
    let height: Int?
    let bitrate: Int?
    let duration: Int?
    let audioChannels: Int?
    let aspectRatio: Double?
    let videoFrameRate: String?
    let parts: [PlexMediaPart]?

    private enum CodingKeys: String, CodingKey {
        case container, videoCodec, audioCodec, videoResolution, width, height, bitrate, duration
        case audioChannels, aspectRatio, videoFrameRate
        case parts = "Part"
    }
}

struct PlexMediaPart: Decodable, Hashable {
    let file: String?
    let size: Int?
    let container: String?
    let duration: Int?
    let streams: [PlexMediaStream]?

    private enum CodingKeys: String, CodingKey {
        case file, size, container, duration
        case streams = "Stream"
    }
}

struct PlexMediaStream: Decodable, Hashable {
    let streamType: Int?
    let codec: String?
    let displayTitle: String?
    let language: String?
    let channels: Int?
    let bitrate: Int?
    let samplingRate: Int?
    let audioChannelLayout: String?
    let width: Int?
    let height: Int?
    let bitDepth: Int?
    let frameRate: Double?
    let profile: String?
    let level: Int?
    let scanType: String?
    let colorSpace: String?
    let colorRange: String?
    let colorTrc: String?
    let forced: Bool?
    let isDefault: Bool?

    private enum CodingKeys: String, CodingKey {
        case streamType, codec, displayTitle, language, channels, bitrate, samplingRate
        case audioChannelLayout, width, height, bitDepth, frameRate, profile, level, scanType
        case colorSpace, colorRange, colorTrc, forced
        case isDefault = "default"
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
            serverURL: serverURL,
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
            releasedAt: releaseTimestamp,
            year: year,
            durationMilliseconds: duration,
            contentRating: contentRating,
            tmdbID: tmdbID,
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
            ),
            detailSections: mediaDetailSections
        )
    }

    private var mediaDetailSections: [MediaItemDetailSection] {
        let identifiers = guid?.map { MediaItemDetailSection.Row(label: "ID", value: $0.id) } ?? []
        var sections = identifiers.isEmpty ? [] : [MediaItemDetailSection(title: "Identifiers", rows: identifiers)]

        for (mediaIndex, media) in (media ?? []).enumerated() {
            let mediaRows: [MediaItemDetailSection.Row?] = [
                media.container.map { .init(label: "Container", value: $0.uppercased()) },
                media.videoCodec.map { .init(label: "Video Codec", value: $0.uppercased()) },
                media.audioCodec.map { .init(label: "Audio Codec", value: $0.uppercased()) },
                media.videoResolution.map { .init(label: "Video Resolution", value: $0) },
                resolution(width: media.width, height: media.height).map { .init(label: "Dimensions", value: $0) },
                media.bitrate.map { .init(label: "Bitrate", value: "\($0) kbps") },
                media.audioChannels.map { .init(label: "Audio Channels", value: String($0)) },
                media.aspectRatio.map { .init(label: "Aspect Ratio", value: String($0)) },
                media.videoFrameRate.map { .init(label: "Frame Rate", value: $0) }
            ]
            sections.append(.init(title: "Media \(mediaIndex + 1)", rows: mediaRows.compactMap { $0 }))

            for (partIndex, part) in (media.parts ?? []).enumerated() {
                let prefix = "File \(partIndex + 1)"
                let partRows: [MediaItemDetailSection.Row?] = [
                    part.file.map { .init(label: "File Name", value: URL(fileURLWithPath: $0).lastPathComponent) },
                    part.file.map { .init(label: "Path", value: $0) },
                    part.size.map { .init(label: "Size", value: ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file)) },
                    part.container.map { .init(label: "Container", value: $0.uppercased()) }
                ]
                sections.append(.init(title: prefix, rows: partRows.compactMap { $0 }))

                for (streamIndex, stream) in (part.streams ?? []).enumerated() {
                    let rows: [MediaItemDetailSection.Row?] = [
                        stream.codec.map { .init(label: "Codec", value: $0.uppercased()) },
                        stream.displayTitle.map { .init(label: "Title", value: $0) },
                        stream.language.map { .init(label: "Language", value: $0) },
                        resolution(width: stream.width, height: stream.height).map { .init(label: "Dimensions", value: $0) },
                        stream.bitrate.map { .init(label: "Bitrate", value: "\($0) kbps") },
                        stream.channels.map { .init(label: "Channels", value: String($0)) },
                        stream.audioChannelLayout.map { .init(label: "Channel Layout", value: $0) },
                        stream.samplingRate.map { .init(label: "Sample Rate", value: "\($0) Hz") },
                        stream.bitDepth.map { .init(label: "Bit Depth", value: "\($0)-bit") },
                        stream.frameRate.map { .init(label: "Frame Rate", value: String($0)) },
                        stream.profile.map { .init(label: "Profile", value: $0) },
                        stream.level.map { .init(label: "Level", value: String($0)) },
                        stream.scanType.map { .init(label: "Scan Type", value: $0) },
                        stream.colorSpace.map { .init(label: "Color Space", value: $0) },
                        stream.colorRange.map { .init(label: "Color Range", value: $0) },
                        stream.colorTrc.map { .init(label: "Color Transfer", value: $0) },
                        stream.isDefault.map { .init(label: "Default", value: $0 ? "Yes" : "No") },
                        stream.forced.map { .init(label: "Forced", value: $0 ? "Yes" : "No") }
                    ]
                    sections.append(.init(
                        title: "\(prefix) · \(streamTitle(stream.streamType)) \(streamIndex + 1)",
                        rows: rows.compactMap { $0 }
                    ))
                }
            }
        }

        return sections.filter { !$0.rows.isEmpty }
    }

    private func resolution(width: Int?, height: Int?) -> String? {
        guard let width, let height else { return nil }
        return "\(width) × \(height)"
    }

    private func streamTitle(_ type: Int?) -> String {
        switch type {
        case 1: "Video"
        case 2: "Audio"
        case 3: "Subtitle"
        default: "Stream"
        }
    }

    private var releaseTimestamp: Int? {
        originallyAvailableAt.flatMap(PlexDateParser.parse).map { Int($0.timeIntervalSince1970) }
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
