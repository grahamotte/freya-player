import XCTest
@testable import FreyaPlayerCore

final class PlaybackCompatibilityTests: XCTestCase {
    func testDirectPlayCodecsIncludeOnlyDetectedNativeFormats() {
        let playableTypes: Set<String> = [
            "video/mp4; codecs=\"avc1.640028\"",
            "video/mp4; codecs=\"hvc1.1.6.L120.B0\"",
            "video/mp4; codecs=\"av01.0.08M.08\"",
            "audio/mp4; codecs=\"mp4a.40.2\"",
            "audio/mp4; codecs=\"ac-3\"",
            "audio/mp4; codecs=\"ec-3\"",
            "audio/mp4; codecs=\"fLaC\"",
        ]
        let isPlayable: (String) -> Bool = { playableTypes.contains($0) }

        XCTAssertEqual(
            PlaybackCompatibility.directPlayVideoCodecs(
                isPlayable: isPlayable,
                hasHardwareAV1Decoder: true
            ),
            ["h264", "avc", "avc1", "hevc", "h265", "hvc1", "av1", "av01"]
        )
        XCTAssertEqual(
            PlaybackCompatibility.directPlayVideoCodecs(
                isPlayable: isPlayable,
                hasHardwareAV1Decoder: false
            ),
            ["h264", "avc", "avc1", "hevc", "h265", "hvc1"]
        )
        XCTAssertEqual(
            PlaybackCompatibility.directPlayAudioCodecs(isPlayable: isPlayable),
            ["aac", "mp4a", "ac3", "ac-3", "eac3", "eac-3", "ec-3", "flac"]
        )
    }

    func testVideoCompatibilityHonorsAnOptionalDisplayResolutionLimit() {
        let videoCodecs: Set<String> = ["h264", "hevc"]

        XCTAssertTrue(PlaybackCompatibility.canDirectPlayVideo(
            codec: "hevc",
            height: 2160,
            supportedCodecs: videoCodecs,
            maximumHeight: nil
        ))
        XCTAssertTrue(PlaybackCompatibility.canDirectPlayVideo(
            codec: "h264",
            height: 1080,
            supportedCodecs: videoCodecs,
            maximumHeight: 1080
        ))
        XCTAssertFalse(PlaybackCompatibility.canDirectPlayVideo(
            codec: "h264",
            height: 2160,
            supportedCodecs: videoCodecs,
            maximumHeight: 1080
        ))
        XCTAssertFalse(PlaybackCompatibility.canDirectPlayVideo(
            codec: "h264",
            height: nil,
            supportedCodecs: videoCodecs,
            maximumHeight: 1080
        ))
        XCTAssertFalse(PlaybackCompatibility.canDirectPlayVideo(
            codec: "av1",
            height: 1080,
            supportedCodecs: videoCodecs,
            maximumHeight: 1080
        ))
        XCTAssertEqual(
            PlaybackCompatibility.maximumVideoHeight(deviceIdentifier: "AppleTV5,3"),
            1080
        )
        XCTAssertNil(PlaybackCompatibility.maximumVideoHeight(deviceIdentifier: "AppleTV6,2"))
        XCTAssertEqual(
            PlaybackCompatibility.effectiveVideoHeight(sourceHeight: 2160, maximumHeight: 1080),
            1080
        )
        XCTAssertEqual(
            PlaybackCompatibility.effectiveVideoHeight(sourceHeight: nil, maximumHeight: 1080),
            1080
        )
        XCTAssertEqual(
            PlaybackCompatibility.effectiveVideoHeight(sourceHeight: 2160, maximumHeight: nil),
            2160
        )
    }

    func testRequiresTranscodedAudioForTvOS27PrereleaseBuilds() {
        XCTAssertTrue(
            PlaybackCompatibility.requiresTranscodedAudio(
                majorVersion: 27,
                versionDescription: "Version 27.0 (Build 24J5346a)"
            )
        )
        XCTAssertFalse(
            PlaybackCompatibility.requiresTranscodedAudio(
                majorVersion: 27,
                versionDescription: "Version 27.0 (Build 24J5346)"
            )
        )
        XCTAssertFalse(
            PlaybackCompatibility.requiresTranscodedAudio(
                majorVersion: 26,
                versionDescription: "Version 26.6 (Build 23M5312a)"
            )
        )
        XCTAssertFalse(
            PlaybackCompatibility.requiresTranscodedAudio(
                majorVersion: 27,
                versionDescription: "Version 27.0"
            )
        )
    }

    func testCapabilitiesDistinguishDetectedConditionalAndUnavailableSupport() {
        let playableTypes: Set<String> = [
            "video/mp4; codecs=\"avc1.640028\"",
            "video/mp4; codecs=\"hvc1.1.6.L120.B0\"",
            "video/mp4; codecs=\"av01.0.08M.08\"",
            "audio/mp4; codecs=\"mp4a.40.2\"",
            "audio/mpeg; codecs=\"mp3\"",
            "audio/mp4; codecs=\"ac-3\"",
            "audio/mp4; codecs=\"ec-3\"",
            "audio/mp4; codecs=\"alac\"",
        ]
        let capabilities = PlaybackCompatibility.capabilities(
            isPlayable: { playableTypes.contains($0) },
            audiovisualMIMETypes: [
                "video/mp4",
                "video/quicktime",
                "text/vtt",
                "application/ttml+xml",
            ],
            hasHardwareAV1Decoder: false,
            isHDREligible: false
        )

        XCTAssertEqual(capabilities.first(where: { $0.name == "H.264" })?.support, .supported)
        XCTAssertEqual(capabilities.first(where: { $0.name == "AV1" })?.support, .conditional)
        XCTAssertEqual(capabilities.first(where: { $0.name == "HDR" })?.support, .conditional)
        XCTAssertEqual(capabilities.first(where: { $0.name == "FLAC" })?.support, .unavailable)
        XCTAssertEqual(capabilities.first(where: { $0.name == "HLS" })?.support, .unavailable)
        XCTAssertEqual(capabilities.first(where: { $0.name == "WebVTT" })?.support, .conditional)
        XCTAssertEqual(capabilities.first(where: { $0.name == "TTML" })?.support, .conditional)
    }
}
