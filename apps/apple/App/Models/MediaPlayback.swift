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
    var descriptionPrefix: String? = nil
}

struct MediaPlaybackOptions: Equatable {
    let qualityOptions: [MediaPlaybackQuality]
    let audioOptions: [MediaPlaybackOption]
    let subtitleOptions: [MediaPlaybackOption]
    let selectedAudioID: String?
    let selectedSubtitleID: String?
}

enum MediaPlaybackQuality: String, CaseIterable, Identifiable {
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
}

struct MediaPlaybackOption: Identifiable, Hashable {
    let id: String
    let title: String
}

struct MediaPlaybackSelection: Equatable {
    let quality: MediaPlaybackQuality
    let audioID: String?
    let subtitleID: String?
}

enum MediaPlaybackTimelineState: String {
    case stopped
    case buffering
    case playing
    case paused
}
