import Foundation

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
