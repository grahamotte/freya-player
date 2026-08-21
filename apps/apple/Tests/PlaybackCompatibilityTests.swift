import XCTest
@testable import FreyaPlayerCore

final class PlaybackCompatibilityTests: XCTestCase {
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
