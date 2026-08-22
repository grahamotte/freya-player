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

    func testCompatibleHEVCInMatroskaIsRemuxedWithoutChangingVideo() throws {
        let source = try mediaSource(
            container: "mkv",
            videoCodec: "hevc",
            audioCodec: "aac",
            supportsDirectPlay: false,
            supportsDirectStream: true,
            dynamicRange: "SDR",
            profile: "Main"
        )
        let options = source.playbackOptions(requiresTranscodedAudio: false)
        let plan = options.playbackPlan(for: MediaPlaybackSelection(
            quality: .automatic,
            audioID: "1",
            subtitleID: nil,
            defaultAudioID: "1"
        ))

        XCTAssertNil(options.defaultVideoTranscoding)
        XCTAssertEqual(plan.path, .remux)
        XCTAssertEqual(plan.conversions[0].description, "Matroska → Fragmented MP4")
        XCTAssertEqual(plan.conversions[1].description, "HEVC • 1080p • SDR")
    }

    func testBT709H264InMatroskaIsRemuxedWithoutChangingVideo() throws {
        let source = try mediaSource(
            container: "mkv",
            videoCodec: "h264",
            audioCodec: "aac",
            supportsDirectPlay: false,
            supportsDirectStream: true,
            dynamicRange: "BT709"
        )
        let options = source.playbackOptions(requiresTranscodedAudio: false)
        let plan = options.playbackPlan(for: MediaPlaybackSelection(
            quality: .automatic,
            audioID: "1",
            subtitleID: nil,
            defaultAudioID: "1"
        ))

        XCTAssertNil(options.defaultVideoTranscoding)
        XCTAssertEqual(plan.path, .remux)
        XCTAssertEqual(plan.conversions[0].description, "Matroska → Fragmented MP4")
        XCTAssertEqual(plan.conversions[1].description, "H.264 • 1080p • SDR")
    }

    func testIncompatibleHEVCFallsBackToH264() throws {
        let source = try mediaSource(
            container: "mkv",
            videoCodec: "hevc",
            audioCodec: "aac",
            supportsDirectPlay: false,
            supportsDirectStream: true,
            dynamicRange: "Dolby Vision",
            profile: "Main 10"
        )
        let options = source.playbackOptions(requiresTranscodedAudio: false)

        XCTAssertEqual(options.defaultVideoTranscoding, "H.264")
        XCTAssertEqual(options.streamingVideoTranscoding, "H.264")
    }

    func testCompatibleHEVCIsPreservedWhileOnlyAudioConverts() throws {
        let source = try mediaSource(
            container: "mkv",
            videoCodec: "hevc",
            audioCodec: "dts",
            supportsDirectPlay: false,
            supportsDirectStream: true,
            dynamicRange: "SDR",
            profile: "Main"
        )
        let options = source.playbackOptions(requiresTranscodedAudio: false)
        let plan = options.playbackPlan(for: MediaPlaybackSelection(
            quality: .automatic,
            audioID: "1",
            subtitleID: nil,
            defaultAudioID: "1"
        ))

        XCTAssertEqual(plan.path, .transcode)
        XCTAssertEqual(plan.conversions[1].description, "HEVC • 1080p • SDR")
        XCTAssertEqual(plan.conversions[2].description, "DTS • Stereo → AAC")
    }

    private func mediaSource(
        container: String,
        videoCodec: String,
        audioCodec: String,
        supportsDirectPlay: Bool,
        supportsDirectStream: Bool,
        dynamicRange: String? = nil,
        profile: String? = nil
    ) throws -> JellyfinMediaSource {
        let dynamicRangeJSON = dynamicRange.map { #", "VideoRangeType": "\#($0)""# } ?? ""
        let profileJSON = profile.map { #", "Profile": "\#($0)""# } ?? ""
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
                  "Height": 1080\(dynamicRangeJSON)\(profileJSON)
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
