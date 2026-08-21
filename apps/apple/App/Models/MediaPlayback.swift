import Foundation

struct MediaPlaybackID: Hashable {
    let providerID: MediaProviderID
    let itemID: String
}

struct MediaPlaybackResource {
    let url: URL
    let localStartOffsetMilliseconds: Int?
    var reloadsForSeek = false
    var remoteSessionID: String? = nil
    var descriptionSuffix: String? = nil
}

struct MediaPlaybackOptions: Equatable {
    let videoHeight: Int?
    let qualityOptions: [MediaPlaybackQuality]
    let audioOptions: [MediaPlaybackOption]
    let subtitleOptions: [MediaPlaybackOption]
    let selectedAudioID: String?
    let selectedSubtitleID: String?
    let defaultVideoTranscoding: String?
    let defaultAudioTranscoding: String?
    let streamingVideoTranscoding: String?
    let sourceContainer: MediaFormat?
    let sourceVideo: MediaFormat?
    let sourceAudio: MediaFormat?
    let streamingContainer: MediaFormat
    let defaultContainerTranscoding: Bool

    init(
        videoHeight: Int?,
        qualityOptions: [MediaPlaybackQuality],
        audioOptions: [MediaPlaybackOption],
        subtitleOptions: [MediaPlaybackOption],
        selectedAudioID: String?,
        selectedSubtitleID: String?,
        defaultVideoTranscoding: String?,
        defaultAudioTranscoding: String?,
        streamingVideoTranscoding: String? = nil,
        sourceContainer: MediaFormat? = nil,
        sourceVideo: MediaFormat? = nil,
        sourceAudio: MediaFormat? = nil,
        streamingContainer: MediaFormat = MediaFormat(name: "HLS"),
        defaultContainerTranscoding: Bool = false
    ) {
        self.videoHeight = videoHeight
        self.qualityOptions = qualityOptions
        self.audioOptions = audioOptions
        self.subtitleOptions = subtitleOptions
        self.selectedAudioID = selectedAudioID
        self.selectedSubtitleID = selectedSubtitleID
        self.defaultVideoTranscoding = defaultVideoTranscoding
        self.defaultAudioTranscoding = defaultAudioTranscoding
        self.streamingVideoTranscoding = streamingVideoTranscoding
        self.sourceContainer = sourceContainer
        self.sourceVideo = sourceVideo
        self.sourceAudio = sourceAudio
        self.streamingContainer = streamingContainer
        self.defaultContainerTranscoding = defaultContainerTranscoding
    }

    var defaultResolutionTitle: String {
        videoHeight.map { "\($0)p (Default)" } ?? "Automatic (Default)"
    }

}

enum MediaPlaybackQuality: String, CaseIterable, Codable, Identifiable {
    case automatic
    case p1080
    case p720
    case p480
    case p240

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .p1080: return "1080p"
        case .p720: return "720p"
        case .p480: return "480p"
        case .p240: return "240p"
        }
    }

    var maxVideoBitrate: Int? {
        switch self {
        case .automatic: return nil
        case .p1080: return 20_000
        case .p720: return 8_000
        case .p480: return 3_000
        case .p240: return 700
        }
    }

    var videoResolution: String? {
        switch self {
        case .automatic: return nil
        case .p1080: return "1080"
        case .p720: return "720"
        case .p480: return "480"
        case .p240: return "240"
        }
    }

    var maxStreamingBitrate: Int? {
        maxVideoBitrate.map { $0 * 1_000 }
    }

    var resolutionHeight: Int? {
        switch self {
        case .automatic: return nil
        case .p1080: return 1080
        case .p720: return 720
        case .p480: return 480
        case .p240: return 240
        }
    }

    static func transcodingOptions(forVideoHeight videoHeight: Int?) -> [MediaPlaybackQuality] {
        allCases.filter { quality in
            guard let resolutionHeight = quality.resolutionHeight else { return false }
            return videoHeight.map { resolutionHeight < $0 } ?? true
        }
    }
}

struct MediaPlaybackOption: Identifiable, Hashable {
    let id: String
    let title: String
    let transcodingTitle: String?
    let sourceFormat: MediaFormat?

    init(
        id: String,
        title: String,
        transcodingTitle: String? = nil,
        sourceFormat: MediaFormat? = nil
    ) {
        self.id = id
        self.title = title
        self.transcodingTitle = transcodingTitle
        self.sourceFormat = sourceFormat
    }
}

struct MediaPlaybackSelection: Equatable {
    let quality: MediaPlaybackQuality
    let audioID: String?
    let subtitleID: String?
    let defaultAudioID: String?
    let defaultSubtitleID: String?

    init(
        quality: MediaPlaybackQuality,
        audioID: String?,
        subtitleID: String?,
        defaultAudioID: String? = nil,
        defaultSubtitleID: String? = nil
    ) {
        self.quality = quality
        self.audioID = audioID
        self.subtitleID = subtitleID
        self.defaultAudioID = defaultAudioID
        self.defaultSubtitleID = defaultSubtitleID
    }
}

struct MediaPlaybackSettings: Codable, Equatable {
    let quality: MediaPlaybackQuality
    let audioID: String?
    let subtitleID: String?

    init(quality: MediaPlaybackQuality, audioID: String?, subtitleID: String?) {
        self.quality = quality
        self.audioID = audioID
        self.subtitleID = subtitleID
    }

    init(selection: MediaPlaybackSelection) {
        self.init(
            quality: selection.quality,
            audioID: selection.audioID,
            subtitleID: selection.subtitleID
        )
    }
}

enum MediaPlaybackTimelineState: String {
    case stopped
    case buffering
    case playing
    case paused
}
