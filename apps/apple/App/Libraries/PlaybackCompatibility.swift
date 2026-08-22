import AVFoundation
import CoreMedia
import Foundation
import VideoToolbox

enum PlaybackCapabilityCategory: String, CaseIterable, Identifiable {
    case containers = "Containers"
    case video = "Video"
    case dynamicRange = "Dynamic Range"
    case audio = "Audio"
    case subtitles = "Subtitles"

    var id: String { rawValue }
}

enum PlaybackCapabilitySupport: Equatable {
    case supported
    case conditional
    case unavailable

    var title: String {
        switch self {
        case .supported: "Supported"
        case .conditional: "Conditional"
        case .unavailable: "Not detected"
        }
    }
}

struct PlaybackCapability: Equatable, Identifiable {
    let category: PlaybackCapabilityCategory
    let name: String
    let support: PlaybackCapabilitySupport
    let detail: String

    var id: String { "\(category.rawValue)-\(name)" }
}

enum PlaybackCompatibility {
    static var directPlayVideoCodecs: Set<String> {
        directPlayVideoCodecs(
            isPlayable: AVURLAsset.isPlayableExtendedMIMEType,
            hasHardwareAV1Decoder: VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)
        )
    }

    static var directPlayAudioCodecs: Set<String> {
        directPlayAudioCodecs(isPlayable: AVURLAsset.isPlayableExtendedMIMEType)
    }

    static var streamingVideoCodecs: Set<String> {
        streamingVideoCodecs(directPlayVideoCodecs: directPlayVideoCodecs)
    }

    static var streamingAudioCodecs: Set<String> {
        directPlayAudioCodecs.intersection(hlsAudioCodecs)
    }

    static var maximumVideoHeight: Int? {
        #if os(tvOS)
        return maximumVideoHeight(deviceIdentifier: deviceIdentifier)
        #else
        return nil
        #endif
    }

    static var deviceCapabilities: [PlaybackCapability] {
        capabilities(
            isPlayable: AVURLAsset.isPlayableExtendedMIMEType,
            audiovisualMIMETypes: Set(AVURLAsset.audiovisualMIMETypes().map { $0.lowercased() }),
            hasHardwareAV1Decoder: VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1),
            isHDREligible: AVPlayer.eligibleForHDRPlayback
        )
    }

    static var requiresTranscodedAudio: Bool {
        #if os(tvOS)
        let processInfo = ProcessInfo.processInfo
        return requiresTranscodedAudio(
            majorVersion: processInfo.operatingSystemVersion.majorVersion,
            versionDescription: processInfo.operatingSystemVersionString
        )
        #else
        return false
        #endif
    }

    static func directPlayVideoCodecs(
        isPlayable: (String) -> Bool,
        hasHardwareAV1Decoder: Bool
    ) -> Set<String> {
        var codecs: Set<String> = []
        if isPlayable(h264MIMEType) { codecs.formUnion(h264Codecs) }
        if isPlayable(hevcMIMEType) || isPlayable(hevcMain10MIMEType) { codecs.formUnion(hevcCodecs) }
        if isPlayable(av1MIMEType) && hasHardwareAV1Decoder { codecs.formUnion(av1Codecs) }
        return codecs
    }

    static func streamingVideoCodecs(directPlayVideoCodecs: Set<String>) -> Set<String> {
        directPlayVideoCodecs.intersection(h264Codecs.union(hevcCodecs))
    }

    static func streamingVideoCodecNames(copying codec: String?, canCopy: Bool) -> [String] {
        guard canCopy, hevcCodecs.contains(codec?.lowercased() ?? "") else { return ["h264"] }
        return ["h264", "hevc"]
    }

    static func directPlayAudioCodecs(isPlayable: (String) -> Bool) -> Set<String> {
        var codecs: Set<String> = []
        for (mimeType, aliases) in audioCodecAliases where isPlayable(mimeType) {
            codecs.formUnion(aliases)
        }
        return codecs
    }

    static func canDirectPlayVideo(
        codec: String?,
        height: Int?,
        supportedCodecs: Set<String>? = nil,
        maximumHeight: Int? = maximumVideoHeight
    ) -> Bool {
        let codecs = supportedCodecs ?? directPlayVideoCodecs
        return codecs.contains(codec?.lowercased() ?? "")
            && supportsVideoHeight(height, maximumHeight: maximumHeight)
    }

    static func canStreamVideo(
        codec: String?,
        height: Int?,
        dynamicRange: String? = nil,
        profile: String? = nil,
        level: Int? = nil,
        bitDepth: Int? = nil,
        isInterlaced: Bool? = nil,
        supportedCodecs: Set<String>? = nil,
        maximumHeight: Int? = maximumVideoHeight,
        supportsHEVCMain10: Bool = AVURLAsset.isPlayableExtendedMIMEType(hevcMain10MIMEType),
        isHDREligible: Bool = AVPlayer.eligibleForHDRPlayback
    ) -> Bool {
        let codecs = supportedCodecs ?? streamingVideoCodecs
        let codec = codec?.lowercased() ?? ""
        guard codecs.contains(codec),
              supportsVideoHeight(height, maximumHeight: maximumHeight) else { return false }

        let dynamicRange = MediaTranscoding.normalizedDynamicRange(dynamicRange)
        guard hevcCodecs.contains(codec) else {
            return dynamicRange == nil || dynamicRange == "sdr"
        }
        guard isInterlaced != true,
              bitDepth.map({ $0 <= 10 }) != false,
              level.map({ $0 <= maximumHEVCLevel }) != false else { return false }

        let normalizedProfile = profile?
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
        guard normalizedProfile.map({ ["main", "main10"].contains($0) }) != false else { return false }

        let requiresMain10 = normalizedProfile == "main10"
            || dynamicRange.map { ["hdr10", "hlg"].contains($0) } == true
        if dynamicRange.map({ ["hdr10", "hlg"].contains($0) }) == true {
            guard normalizedProfile.map({ $0 == "main10" }) != false,
                  bitDepth.map({ $0 == 10 }) != false else { return false }
        }
        guard !requiresMain10 || supportsHEVCMain10 else { return false }
        return switch dynamicRange {
        case nil, "sdr": true
        case "hdr10", "hlg": isHDREligible
        default: false
        }
    }

    static func maximumVideoHeight(deviceIdentifier: String) -> Int? {
        deviceIdentifier == "AppleTV5,3" ? 1080 : nil
    }

    static func effectiveVideoHeight(sourceHeight: Int?, maximumHeight: Int? = maximumVideoHeight) -> Int? {
        guard let maximumHeight else { return sourceHeight }
        return min(sourceHeight ?? maximumHeight, maximumHeight)
    }

    static func requiresTranscodedAudio(
        majorVersion: Int,
        versionDescription: String
    ) -> Bool {
        guard majorVersion == 27,
              let start = versionDescription.range(of: "(Build ", options: .backwards),
              let end = versionDescription[start.upperBound...].firstIndex(of: ")") else {
            return false
        }

        let buildIdentifier = versionDescription[start.upperBound..<end]
        guard let suffix = buildIdentifier.unicodeScalars.last else { return false }
        return (UnicodeScalar("a").value...UnicodeScalar("z").value).contains(suffix.value)
    }

    static func capabilities(
        isPlayable: (String) -> Bool,
        audiovisualMIMETypes: Set<String>,
        hasHardwareAV1Decoder: Bool,
        isHDREligible: Bool
    ) -> [PlaybackCapability] {
        let av1Playable = isPlayable(av1MIMEType)
        let av1Detail: String
        if av1Playable && hasHardwareAV1Decoder {
            av1Detail = "Native playback and hardware decode detected."
        } else if av1Playable {
            av1Detail = "Native playback detected without a hardware decoder guarantee."
        } else {
            av1Detail = "Native playback was not reported."
        }
        return [
            containerCapability(
                name: "MP4 / M4V",
                mimeTypes: ["video/mp4"],
                audiovisualMIMETypes: audiovisualMIMETypes
            ),
            containerCapability(
                name: "QuickTime",
                mimeTypes: ["video/quicktime"],
                audiovisualMIMETypes: audiovisualMIMETypes
            ),
            containerCapability(
                name: "HLS",
                mimeTypes: ["application/vnd.apple.mpegurl", "application/x-mpegurl"],
                audiovisualMIMETypes: audiovisualMIMETypes
            ),
            codecCapability(
                category: .video,
                name: "H.264",
                mimeType: h264MIMEType,
                isPlayable: isPlayable
            ),
            codecCapability(
                category: .video,
                name: "HEVC",
                isSupported: isPlayable(hevcMIMEType) || isPlayable(hevcMain10MIMEType)
            ),
            PlaybackCapability(
                category: .video,
                name: "AV1",
                support: av1Playable && hasHardwareAV1Decoder
                    ? .supported
                    : av1Playable ? .conditional : .unavailable,
                detail: av1Detail
            ),
            PlaybackCapability(
                category: .dynamicRange,
                name: "HDR",
                support: isHDREligible ? .supported : .conditional,
                detail: isHDREligible
                    ? "The current display route is eligible for HDR playback."
                    : "Availability depends on the current device and display route."
            ),
            codecCapability(
                category: .audio,
                name: "AAC",
                mimeType: aacMIMEType,
                isPlayable: isPlayable
            ),
            codecCapability(
                category: .audio,
                name: "MP3",
                mimeType: mp3MIMEType,
                isPlayable: isPlayable
            ),
            codecCapability(
                category: .audio,
                name: "AC-3",
                mimeType: ac3MIMEType,
                isPlayable: isPlayable,
                detail: "Decode support; channel output depends on the current audio route."
            ),
            codecCapability(
                category: .audio,
                name: "E-AC-3",
                mimeType: eac3MIMEType,
                isPlayable: isPlayable,
                detail: "Decode support; channel output depends on the current audio route."
            ),
            codecCapability(
                category: .audio,
                name: "ALAC",
                mimeType: alacMIMEType,
                isPlayable: isPlayable
            ),
            codecCapability(
                category: .audio,
                name: "FLAC",
                mimeType: flacMIMEType,
                isPlayable: isPlayable
            ),
            PlaybackCapability(
                category: .audio,
                name: "Surround output",
                support: .conditional,
                detail: "Channel layout depends on the current audio route."
            ),
            subtitleCapability(
                name: "WebVTT",
                mimeType: "text/vtt",
                audiovisualMIMETypes: audiovisualMIMETypes
            ),
            subtitleCapability(
                name: "TTML",
                mimeType: "application/ttml+xml",
                audiovisualMIMETypes: audiovisualMIMETypes
            ),
        ]
    }

    private static func containerCapability(
        name: String,
        mimeTypes: Set<String>,
        audiovisualMIMETypes: Set<String>
    ) -> PlaybackCapability {
        let isSupported = !mimeTypes.isDisjoint(with: audiovisualMIMETypes)
        return PlaybackCapability(
            category: .containers,
            name: name,
            support: isSupported ? .supported : .unavailable,
            detail: isSupported ? "Recognized by AVFoundation." : "Not reported by AVFoundation."
        )
    }

    private static func codecCapability(
        category: PlaybackCapabilityCategory,
        name: String,
        mimeType: String,
        isPlayable: (String) -> Bool,
        detail: String? = nil
    ) -> PlaybackCapability {
        codecCapability(
            category: category,
            name: name,
            isSupported: isPlayable(mimeType),
            detail: detail
        )
    }

    private static func codecCapability(
        category: PlaybackCapabilityCategory,
        name: String,
        isSupported: Bool,
        detail: String? = nil
    ) -> PlaybackCapability {
        return PlaybackCapability(
            category: category,
            name: name,
            support: isSupported ? .supported : .unavailable,
            detail: detail ?? (isSupported ? "Native playback detected." : "Native playback was not reported.")
        )
    }

    private static func subtitleCapability(
        name: String,
        mimeType: String,
        audiovisualMIMETypes: Set<String>
    ) -> PlaybackCapability {
        let isRecognized = audiovisualMIMETypes.contains(mimeType)
        return PlaybackCapability(
            category: .subtitles,
            name: name,
            support: isRecognized ? .conditional : .unavailable,
            detail: isRecognized
                ? "Recognized by AVFoundation; delivery support varies by container."
                : "Not reported by AVFoundation."
        )
    }

    private static func supportsVideoHeight(_ height: Int?, maximumHeight: Int?) -> Bool {
        guard let maximumHeight else { return true }
        guard let height else { return false }
        return height <= maximumHeight
    }

    private static var deviceIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    private static let h264MIMEType = "video/mp4; codecs=\"avc1.640028\""
    private static let hevcMIMEType = "video/mp4; codecs=\"hvc1.1.6.L120.B0\""
    private static let hevcMain10MIMEType = "video/mp4; codecs=\"hvc1.2.4.L153.B0\""
    private static let av1MIMEType = "video/mp4; codecs=\"av01.0.08M.08\""
    private static let aacMIMEType = "audio/mp4; codecs=\"mp4a.40.2\""
    private static let mp3MIMEType = "audio/mpeg; codecs=\"mp3\""
    private static let ac3MIMEType = "audio/mp4; codecs=\"ac-3\""
    private static let eac3MIMEType = "audio/mp4; codecs=\"ec-3\""
    private static let alacMIMEType = "audio/mp4; codecs=\"alac\""
    private static let flacMIMEType = "audio/mp4; codecs=\"fLaC\""
    private static let h264Codecs: Set<String> = ["h264", "avc", "avc1"]
    private static let hevcCodecs: Set<String> = ["hevc", "h265", "hvc1"]
    private static let av1Codecs: Set<String> = ["av1", "av01"]
    private static let maximumHEVCLevel = 153
    private static let hlsAudioCodecs: Set<String> = [
        "aac", "mp4a", "mp3", "ac3", "ac-3", "eac3", "eac-3", "ec-3",
    ]
    private static let audioCodecAliases: [(String, Set<String>)] = [
        (aacMIMEType, ["aac", "mp4a"]),
        (mp3MIMEType, ["mp3"]),
        (ac3MIMEType, ["ac3", "ac-3"]),
        (eac3MIMEType, ["eac3", "eac-3", "ec-3"]),
        (alacMIMEType, ["alac"]),
        (flacMIMEType, ["flac"]),
    ]
}
