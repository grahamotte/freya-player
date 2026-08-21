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
        let av1Playable = isPlayable("video/mp4; codecs=\"av01.0.08M.08\"")
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
                mimeType: "video/mp4; codecs=\"avc1.640028\"",
                isPlayable: isPlayable
            ),
            codecCapability(
                category: .video,
                name: "HEVC",
                mimeType: "video/mp4; codecs=\"hvc1.1.6.L120.B0\"",
                isPlayable: isPlayable
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
                mimeType: "audio/mp4; codecs=\"mp4a.40.2\"",
                isPlayable: isPlayable
            ),
            codecCapability(
                category: .audio,
                name: "MP3",
                mimeType: "audio/mpeg; codecs=\"mp3\"",
                isPlayable: isPlayable
            ),
            codecCapability(
                category: .audio,
                name: "AC-3",
                mimeType: "audio/mp4; codecs=\"ac-3\"",
                isPlayable: isPlayable,
                detail: "Decode support; channel output depends on the current audio route."
            ),
            codecCapability(
                category: .audio,
                name: "E-AC-3",
                mimeType: "audio/mp4; codecs=\"ec-3\"",
                isPlayable: isPlayable,
                detail: "Decode support; channel output depends on the current audio route."
            ),
            codecCapability(
                category: .audio,
                name: "ALAC",
                mimeType: "audio/mp4; codecs=\"alac\"",
                isPlayable: isPlayable
            ),
            codecCapability(
                category: .audio,
                name: "FLAC",
                mimeType: "audio/mp4; codecs=\"fLaC\"",
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
        let isSupported = isPlayable(mimeType)
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
}
