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
}
