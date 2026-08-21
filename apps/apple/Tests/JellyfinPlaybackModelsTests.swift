import XCTest
@testable import FreyaPlayerCore

final class JellyfinPlaybackModelsTests: XCTestCase {
    func testUnsupportedDeviceVideoOverridesServerDirectPlayClaim() throws {
        let source = try mediaSource(
            container: "mp4",
            videoCodec: "vp9",
            audioCodec: "aac",
            supportsDirectPlay: true,
            supportsDirectStream: true
        )
        let options = source.playbackOptions(requiresTranscodedAudio: false)
        let plan = options.playbackPlan(for: MediaPlaybackSelection(
            quality: .automatic,
            audioID: "1",
            subtitleID: nil,
            defaultAudioID: "1"
        ))

        XCTAssertFalse(source.isDirectPlayable)
        XCTAssertEqual(options.defaultVideoTranscoding, "H.264")
        XCTAssertTrue(options.defaultContainerTranscoding)
        XCTAssertEqual(plan.path, .transcode)
        XCTAssertEqual(
            plan.conversions.first(where: { $0.element == .video })?.description,
            "VP9 • 1080p → H.264"
        )
    }

    func testStreamingMethodReportsOnlyVideoConversionAsTranscoding() {
        XCTAssertEqual(
            JellyfinPlaybackMethod.streaming(
                supportsDirectStream: true,
                canCopyVideo: true,
                quality: .automatic
            ),
            .directStream
        )
        XCTAssertEqual(
            JellyfinPlaybackMethod.streaming(
                supportsDirectStream: true,
                canCopyVideo: false,
                quality: .automatic
            ),
            .transcode
        )
        XCTAssertEqual(
            JellyfinPlaybackMethod.streaming(
                supportsDirectStream: true,
                canCopyVideo: true,
                quality: .p720
            ),
            .transcode
        )
        XCTAssertEqual(
            JellyfinPlaybackMethod.streaming(
                supportsDirectStream: false,
                canCopyVideo: true,
                quality: .automatic
            ),
            .transcode
        )
    }

    private func mediaSource(
        container: String,
        videoCodec: String,
        audioCodec: String,
        supportsDirectPlay: Bool,
        supportsDirectStream: Bool
    ) throws -> JellyfinMediaSource {
        let data = Data(
            """
            {
              "Container": "\(container)",
              "SupportsDirectPlay": \(supportsDirectPlay),
              "SupportsDirectStream": \(supportsDirectStream),
              "SupportsTranscoding": true,
              "DefaultAudioStreamIndex": 1,
              "MediaStreams": [
                {
                  "Index": 0,
                  "Type": "Video",
                  "Codec": "\(videoCodec)",
                  "IsDefault": true,
                  "Height": 1080
                },
                {
                  "Index": 1,
                  "Type": "Audio",
                  "Codec": "\(audioCodec)",
                  "IsDefault": true,
                  "Channels": 2
                }
              ]
            }
            """.utf8
        )
        return try JSONDecoder().decode(JellyfinMediaSource.self, from: data)
    }
}
