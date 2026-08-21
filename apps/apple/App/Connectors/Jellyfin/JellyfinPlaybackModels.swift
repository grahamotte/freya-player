import Foundation

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
    let mediaStreams: [JellyfinMediaStream]?
    let defaultAudioStreamIndex: Int?
    let defaultSubtitleStreamIndex: Int?

    var directPlayContainer: String? {
        ["mp4", "m4v", "mov"].first { container?.lowercased().split(separator: ",").contains(Substring($0)) == true }
    }

    var isDirectPlayable: Bool {
        guard directPlayContainer != nil,
              let video = mediaStreams?.first(where: { $0.type == "Video" }),
              PlaybackCompatibility.canDirectPlayVideo(codec: video.codec, height: video.height),
              let audio = selectedAudioStream(selection: nil) else { return false }
        return PlaybackCompatibility.directPlayAudioCodecs.contains(audio.codec?.lowercased() ?? "")
    }

    var videoHeight: Int? {
        mediaStreams?.first(where: { $0.type == "Video" })?.height
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
        let sourceVideoHeight = video?.height
        let defaultVideoHeight = PlaybackCompatibility.effectiveVideoHeight(
            sourceHeight: sourceVideoHeight
        )
        let requiresServerStream = !supportsDirectPlay || !isDirectPlayable
        let canDirectStreamVideo = PlaybackCompatibility.canStreamVideo(
            codec: video?.codec,
            height: video?.height
        )
        let transcodesVideo = requiresServerStream && (!supportsDirectStream || !canDirectStreamVideo)
        let transcodesAllAudio = requiresTranscodedAudio || (requiresServerStream && !supportsDirectStream)
        let audioOptions = streams
            .filter { $0.type == "Audio" }
            .map { stream in
                let canDirectStream = PlaybackCompatibility.streamingAudioCodecs.contains(
                    stream.codec?.lowercased() ?? ""
                )
                return MediaPlaybackOption(
                    id: String(stream.index),
                    title: stream.displayTitle ?? stream.language ?? "Audio \(stream.index)",
                    transcodingTitle: transcodesAllAudio || !canDirectStream ? "AAC" : nil,
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
        let selectedAudioStream = selectedAudioStream(selection: nil)
        let defaultAudioTranscoding = selectedAudioID.flatMap { audioID in
            audioOptions.first(where: { $0.id == audioID })?.transcodingTitle
        }

        return MediaPlaybackOptions(
            videoHeight: defaultVideoHeight,
            qualityOptions: MediaPlaybackQuality.transcodingOptions(forVideoHeight: defaultVideoHeight),
            audioOptions: audioOptions,
            subtitleOptions: subtitleOptions,
            selectedAudioID: selectedAudioID,
            selectedSubtitleID: selectedSubtitleID,
            defaultVideoTranscoding: transcodesVideo ? "H.264" : nil,
            defaultAudioTranscoding: defaultAudioTranscoding,
            streamingVideoTranscoding: canDirectStreamVideo ? nil : "H.264",
            sourceContainer: MediaTranscoding.container(container),
            sourceVideo: MediaTranscoding.video(
                codec: video?.codec,
                height: sourceVideoHeight,
                dynamicRange: video?.videoRangeType ?? video?.videoRange
            ),
            sourceAudio: MediaTranscoding.audio(
                codec: selectedAudioStream?.codec,
                channels: selectedAudioStream?.channels,
                channelLayout: selectedAudioStream?.channelLayout
            ),
            defaultContainerTranscoding: requiresServerStream
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
        return PlaybackCompatibility.canStreamVideo(codec: video?.codec, height: video?.height)
    }

    func canCopyAudio(selection: MediaPlaybackSelection?) -> Bool {
        let audio = selectedAudioStream(selection: selection)
        return PlaybackCompatibility.streamingAudioCodecs.contains(audio?.codec?.lowercased() ?? "")
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

enum JellyfinPlaybackMethod: String {
    case transcode = "Transcode"
    case directStream = "DirectStream"
    case directPlay = "DirectPlay"

    static func streaming(
        supportsDirectStream: Bool,
        canCopyVideo: Bool,
        quality: MediaPlaybackQuality
    ) -> JellyfinPlaybackMethod {
        supportsDirectStream && canCopyVideo && quality == .automatic ? .directStream : .transcode
    }
}
