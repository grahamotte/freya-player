import XCTest
@testable import FreyaPlayerCore

final class MediaPlaybackTests: XCTestCase {
    func testQualityMetadata() {
        XCTAssertEqual(MediaPlaybackQuality.automatic.title, "Automatic")
        XCTAssertNil(MediaPlaybackQuality.automatic.maxStreamingBitrate)
        XCTAssertEqual(MediaPlaybackQuality.p1080.maxVideoBitrate, 20_000)
        XCTAssertEqual(MediaPlaybackQuality.p720.videoResolution, "720")
        XCTAssertEqual(MediaPlaybackQuality.p240.maxStreamingBitrate, 700_000)
    }

    func testQualityOptionsOnlyStepDownFromSourceResolution() {
        XCTAssertEqual(
            MediaPlaybackQuality.transcodingOptions(forVideoHeight: 720),
            [.p480, .p240]
        )
        XCTAssertEqual(
            MediaPlaybackQuality.transcodingOptions(forVideoHeight: 2160),
            [.p1080, .p720, .p480, .p240]
        )
    }

    func testPlaybackOptionsDescribeDefaultsAndTranscoding() {
        let options = MediaPlaybackOptions(
            videoHeight: 1440,
            qualityOptions: MediaPlaybackQuality.transcodingOptions(forVideoHeight: 1440),
            audioOptions: [
                MediaPlaybackOption(id: "english", title: "English"),
                MediaPlaybackOption(id: "french", title: "French", transcodingTitle: "AAC"),
            ],
            subtitleOptions: [],
            selectedAudioID: "english",
            selectedSubtitleID: nil,
            defaultVideoTranscoding: nil,
            defaultAudioTranscoding: nil
        )

        XCTAssertEqual(options.defaultResolutionTitle, "1440p (Default)")
        XCTAssertEqual(
            options.transcodingSummary(for: MediaPlaybackSelection(
                quality: .p720,
                audioID: "french",
                subtitleID: nil
            )),
            MediaPlaybackTranscodingSummary(video: "H.264 at 720p", audio: "AAC")
        )
    }

    func testPlaybackSettingsCaptureOnlyUserChoices() {
        let selection = MediaPlaybackSelection(
            quality: .p720,
            audioID: "french",
            subtitleID: nil,
            defaultAudioID: "english",
            defaultSubtitleID: "english-forced"
        )

        XCTAssertEqual(
            MediaPlaybackSettings(selection: selection),
            MediaPlaybackSettings(quality: .p720, audioID: "french", subtitleID: nil)
        )
    }
}
