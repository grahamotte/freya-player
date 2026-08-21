import Foundation

struct MediaFormat: Equatable, Hashable {
    let name: String
    let details: [String]

    init(name: String?, details: [String] = []) {
        self.name = MediaTranscoding.displayName(for: name)
        self.details = details
            .filter(\.isPresent)
            .reduce(into: []) { result, detail in
                if !result.contains(detail) {
                    result.append(detail)
                }
            }
    }

    var description: String {
        ([name] + details).joined(separator: " • ")
    }
}

enum MediaPlaybackElement: String, CaseIterable, Identifiable {
    case container = "Container"
    case video = "Video"
    case audio = "Audio"
    case subtitles = "Subtitles"

    var id: String { rawValue }
}

enum MediaPlaybackPath: String, Equatable {
    case directPlay = "Direct Play"
    case remux = "Remux"
    case transcode = "Transcode"
}

struct MediaPlaybackConversion: Equatable, Identifiable {
    let element: MediaPlaybackElement
    let source: MediaFormat?
    let output: MediaFormat?

    var id: MediaPlaybackElement { element }

    var description: String {
        guard source != nil || output != nil else {
            return element == .subtitles ? "None" : "Unknown"
        }
        guard let output else {
            return source?.description ?? "Unknown"
        }
        guard source != output else { return output.description }
        return "\(source?.description ?? "Unknown") → \(output.description)"
    }

    var isConverted: Bool {
        output != nil && source != output
    }
}

struct MediaPlaybackPlan: Equatable {
    let path: MediaPlaybackPath
    let conversions: [MediaPlaybackConversion]

    var playerDescription: String {
        let sources = conversions.compactMap { conversion in
            conversion.source.map { "\(conversion.element.rawValue) \($0.description)" }
        }
        let playback = conversions.map { "\($0.element.rawValue): \($0.description)" }
        return [
            sources.isEmpty ? nil : "Source: \(sources.joined(separator: " • "))",
            playback.isEmpty ? nil : playback.joined(separator: "\n"),
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }
}

extension MediaPlaybackOptions {
    func playbackPlan(for selection: MediaPlaybackSelection) -> MediaPlaybackPlan {
        let audioOption = selection.audioID.flatMap { audioID in
            audioOptions.first(where: { $0.id == audioID })
        }
        let audioTarget = audioOption?.transcodingTitle.map { MediaFormat(name: $0) }
            ?? (selection.audioID == selectedAudioID ? defaultAudioTranscoding.map { MediaFormat(name: $0) } : nil)
        let subtitleOption = selection.subtitleID.flatMap { subtitleID in
            subtitleOptions.first(where: { $0.id == subtitleID })
        }
        let subtitleTarget = subtitleOption?.transcodingTitle.map { MediaFormat(name: $0) }
        let changesAudio = selection.audioID != nil && selection.audioID != selectedAudioID
        let requiresStreamingContainer = defaultContainerTranscoding
            || defaultVideoTranscoding != nil
            || audioTarget != nil
            || changesAudio
            || selection.subtitleID != nil
            || selection.quality != .automatic
        let videoTarget: MediaFormat? = if selection.quality != .automatic {
            MediaFormat(name: "H.264", details: [selection.quality.title])
        } else if let defaultVideoTranscoding {
            MediaFormat(name: defaultVideoTranscoding)
        } else if requiresStreamingContainer, let streamingVideoTranscoding {
            MediaFormat(name: streamingVideoTranscoding)
        } else {
            nil
        }

        let conversions = [
            MediaPlaybackConversion(
                element: .container,
                source: sourceContainer,
                output: requiresStreamingContainer ? streamingContainer : nil
            ),
            MediaPlaybackConversion(element: .video, source: sourceVideo, output: videoTarget),
            MediaPlaybackConversion(
                element: .audio,
                source: audioOption?.sourceFormat ?? sourceAudio,
                output: audioTarget
            ),
            MediaPlaybackConversion(
                element: .subtitles,
                source: subtitleOption?.sourceFormat,
                output: subtitleTarget
            ),
        ]
        let path: MediaPlaybackPath = if conversions.contains(where: {
            $0.element != .container && $0.isConverted
        }) {
            .transcode
        } else if conversions.contains(where: { $0.element == .container && $0.isConverted }) {
            .remux
        } else {
            .directPlay
        }
        return MediaPlaybackPlan(path: path, conversions: conversions)
    }
}

enum MediaTranscoding {
    static func container(_ name: String?) -> MediaFormat? {
        name.map { MediaFormat(name: $0) }
    }

    static func video(
        codec: String?,
        resolution: String? = nil,
        height: Int? = nil,
        dynamicRange: String? = nil
    ) -> MediaFormat? {
        guard codec != nil || resolution != nil || height != nil || dynamicRange != nil else { return nil }
        return MediaFormat(
            name: codec,
            details: [
                resolutionTitle(resolution, height: height),
                dynamicRangeTitle(dynamicRange),
            ].compactMap { $0 }
        )
    }

    static func audio(codec: String?, channels: Int? = nil, channelLayout: String? = nil) -> MediaFormat? {
        guard codec != nil || channels != nil || channelLayout != nil else { return nil }
        return MediaFormat(
            name: codec,
            details: [channelLayoutTitle(channelLayout, channels: channels)].compactMap { $0 }
        )
    }

    static func subtitles(codec: String?, isExternal: Bool = false) -> MediaFormat? {
        guard codec != nil else { return nil }
        return MediaFormat(name: codec, details: isExternal ? ["External"] : [])
    }

    static func displayName(for value: String?) -> String {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), value.isPresent else {
            return "Unknown"
        }
        return switch value.lowercased() {
        case "mp4", "m4v": "MP4"
        case "mov": "QuickTime"
        case "mkv", "matroska": "Matroska"
        case "mpegts", "mpeg-ts", "ts": "MPEG-TS"
        case "hls": "HLS"
        case "h264", "avc", "avc1": "H.264"
        case "hevc", "h265", "hvc1", "hev1": "HEVC"
        case "av1", "av01": "AV1"
        case "mpeg4": "MPEG-4 Video"
        case "aac", "mp4a": "AAC"
        case "ac3", "ac-3": "AC-3"
        case "eac3", "eac-3", "ec-3": "E-AC-3"
        case "truehd": "Dolby TrueHD"
        case "dca", "dts": "DTS"
        case "mp3": "MP3"
        case "alac": "ALAC"
        case "flac": "FLAC"
        case "opus": "Opus"
        case "subrip", "srt": "SRT"
        case "ass": "ASS"
        case "ssa": "SSA"
        case "webvtt", "vtt": "WebVTT"
        case "pgs", "pgssub": "PGS"
        case "vobsub", "dvd_subtitle": "VobSub"
        case "burned into video": "Burned into video"
        default: value.uppercased()
        }
    }

    static func channelLayoutTitle(_ layout: String?, channels: Int?) -> String? {
        if let layout = layout?.trimmingCharacters(in: .whitespacesAndNewlines), layout.isPresent {
            return layout
        }
        return switch channels {
        case 1: "Mono"
        case 2: "Stereo"
        case 6: "5.1"
        case 8: "7.1"
        case let channels?: "\(channels) channels"
        case nil: nil
        }
    }

    private static func resolutionTitle(_ resolution: String?, height: Int?) -> String? {
        if let resolution = resolution?.trimmingCharacters(in: .whitespacesAndNewlines), resolution.isPresent {
            return switch resolution.lowercased() {
            case "4k": "4K"
            case "8k": "8K"
            case let value where value.hasSuffix("p"): value
            default: "\(resolution)p"
            }
        }
        return height.map { "\($0)p" }
    }

    private static func dynamicRangeTitle(_ dynamicRange: String?) -> String? {
        guard let dynamicRange = dynamicRange?.trimmingCharacters(in: .whitespacesAndNewlines),
              dynamicRange.isPresent else { return nil }
        return switch dynamicRange.lowercased() {
        case "dovi", "dolbyvision", "dolby vision": "Dolby Vision"
        case "hdr", "hdr10": "HDR10"
        case "hlg": "HLG"
        case "sdr": "SDR"
        case "smpte2084", "smpte st 2084": "HDR10"
        case "arib-std-b67": "HLG"
        default: dynamicRange.uppercased()
        }
    }
}

private extension String {
    var isPresent: Bool {
        !trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
