import XCTest
@testable import FreyaPlayerCore

final class MediaTranscodingTests: XCTestCase {
    func testFormatsUseFriendlyCodecResolutionRangeAndChannelNames() {
        XCTAssertEqual(
            MediaTranscoding.video(codec: "h265", resolution: "4k", dynamicRange: "smpte2084"),
            MediaFormat(name: "HEVC", details: ["4K", "HDR10"])
        )
        XCTAssertEqual(
            MediaTranscoding.audio(codec: "eac3", channels: 6),
            MediaFormat(name: "E-AC-3", details: ["5.1"])
        )
        XCTAssertEqual(
            MediaTranscoding.subtitles(codec: "subrip", isExternal: true),
            MediaFormat(name: "SRT", details: ["External"])
        )
    }

    func testDirectPlayPlanShowsEveryKnownSourceAndNoSubtitles() {
        let options = playbackOptions(audioTranscoding: false)
        let plan = options.playbackPlan(for: MediaPlaybackSelection(
            quality: .automatic,
            audioID: "audio",
            subtitleID: nil,
            defaultAudioID: "audio",
            defaultSubtitleID: nil
        ))

        XCTAssertEqual(plan.path, .directPlay)
        XCTAssertEqual(
            plan.conversions.map(\.description),
            [
                "MP4",
                "HEVC • 4K • HDR10",
                "E-AC-3 • 5.1",
                "None",
            ]
        )
    }

    func testQualityAudioAndSubtitleChoicesDescribeEveryConversion() {
        let options = playbackOptions(audioTranscoding: true)
        let plan = options.playbackPlan(for: MediaPlaybackSelection(
            quality: .p1080,
            audioID: "audio",
            subtitleID: "subtitle",
            defaultAudioID: "audio",
            defaultSubtitleID: nil
        ))

        XCTAssertEqual(plan.path, .transcode)
        XCTAssertEqual(
            plan.conversions.map(\.description),
            [
                "MP4 → MPEG-TS",
                "HEVC • 4K • HDR10 → H.264 • 1080p",
                "E-AC-3 • 5.1 → AAC",
                "SRT • External → WebVTT",
            ]
        )
    }

    func testContainerOnlyChangeIsARemux() {
        let options = MediaPlaybackOptions(
            videoHeight: 1080,
            qualityOptions: [],
            audioOptions: [],
            subtitleOptions: [],
            selectedAudioID: nil,
            selectedSubtitleID: nil,
            defaultVideoTranscoding: nil,
            defaultAudioTranscoding: nil,
            sourceContainer: MediaTranscoding.container("mkv"),
            sourceVideo: MediaTranscoding.video(codec: "h264", height: 1080),
            sourceAudio: MediaTranscoding.audio(codec: "aac", channels: 2),
            defaultContainerTranscoding: true
        )
        let plan = options.playbackPlan(for: MediaPlaybackSelection(
            quality: .automatic,
            audioID: nil,
            subtitleID: nil
        ))

        XCTAssertEqual(plan.path, .remux)
        XCTAssertEqual(plan.conversions.first?.description, "Matroska → MPEG-TS")
        XCTAssertEqual(plan.conversions.count, 4)
        XCTAssertEqual(plan.conversions.last?.description, "None")
    }

    func testPlayingFormatsAlwaysDescribeFourResolvedValuesWithoutSources() {
        let formats = MediaPlaybackFormats(
            container: MediaTranscoding.container("mpegts"),
            video: MediaTranscoding.video(codec: "h264", height: 1080),
            audio: MediaTranscoding.audio(codec: "aac", channels: 6),
            subtitles: nil
        )

        XCTAssertEqual(
            formats.playerDescription,
            """
            Container: MPEG-TS
            Video: H.264 • 1080p
            Audio: AAC • 5.1
            Subtitles: None
            """
        )
    }

    func testHLSManifestDescribesActualOutputFormats() {
        let manifest = """
        #EXTM3U
        #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",URI="subtitles.m3u8"
        #EXT-X-STREAM-INF:BANDWIDTH=8000000,RESOLUTION=1920x1080,CODECS="avc1.640028,mp4a.40.2",SUBTITLES="subs"
        main.m3u8
        """

        XCTAssertEqual(
            MediaTranscoding.hlsPlaybackFormats(
                manifest: manifest,
                subtitles: MediaTranscoding.subtitles(codec: "webvtt")
            ),
            MediaPlaybackFormats(
                container: MediaTranscoding.container("mpegts"),
                video: MediaTranscoding.video(codec: "h264", height: 1080),
                audio: MediaTranscoding.audio(codec: "aac"),
                subtitles: MediaTranscoding.subtitles(codec: "webvtt")
            )
        )
    }

    func testOnlyTextSubtitlesCanBeStreamedWithoutBurnIn() {
        XCTAssertTrue(MediaTranscoding.canStreamSubtitle(codec: "srt"))
        XCTAssertTrue(MediaTranscoding.canStreamSubtitle(codec: "ass"))
        XCTAssertFalse(MediaTranscoding.canStreamSubtitle(codec: "pgs"))
        XCTAssertFalse(MediaTranscoding.canStreamSubtitle(codec: "dvd_subtitle"))
    }

    func testStreamingPathCanConvertVideoThatDirectPlayPreserves() {
        let options = MediaPlaybackOptions(
            videoHeight: 2160,
            qualityOptions: [.p1080],
            audioOptions: [
                MediaPlaybackOption(
                    id: "default",
                    title: "English",
                    sourceFormat: MediaTranscoding.audio(codec: "aac", channels: 2)
                ),
                MediaPlaybackOption(
                    id: "alternate",
                    title: "Commentary",
                    sourceFormat: MediaTranscoding.audio(codec: "aac", channels: 2)
                ),
            ],
            subtitleOptions: [],
            selectedAudioID: "default",
            selectedSubtitleID: nil,
            defaultVideoTranscoding: nil,
            defaultAudioTranscoding: nil,
            streamingVideoTranscoding: "H.264",
            sourceContainer: MediaTranscoding.container("mp4"),
            sourceVideo: MediaTranscoding.video(codec: "hevc", resolution: "4k"),
            sourceAudio: MediaTranscoding.audio(codec: "aac", channels: 2)
        )

        let directPlan = options.playbackPlan(for: MediaPlaybackSelection(
            quality: .automatic,
            audioID: "default",
            subtitleID: nil,
            defaultAudioID: "default"
        ))
        let alternateTrackPlan = options.playbackPlan(for: MediaPlaybackSelection(
            quality: .automatic,
            audioID: "alternate",
            subtitleID: nil,
            defaultAudioID: "default"
        ))

        XCTAssertEqual(directPlan.path, .directPlay)
        XCTAssertEqual(directPlan.conversions.first(where: { $0.element == .video })?.description, "HEVC • 4K")
        XCTAssertEqual(alternateTrackPlan.path, .transcode)
        XCTAssertEqual(alternateTrackPlan.conversions.first(where: { $0.element == .video })?.description, "HEVC • 4K → H.264")
    }

    private func playbackOptions(audioTranscoding: Bool) -> MediaPlaybackOptions {
        MediaPlaybackOptions(
            videoHeight: 2160,
            qualityOptions: [.p1080, .p720],
            audioOptions: [
                MediaPlaybackOption(
                    id: "audio",
                    title: "English",
                    transcodingTitle: audioTranscoding ? "AAC" : nil,
                    sourceFormat: MediaTranscoding.audio(codec: "eac3", channels: 6)
                ),
            ],
            subtitleOptions: [
                MediaPlaybackOption(
                    id: "subtitle",
                    title: "English",
                    transcodingTitle: "WebVTT",
                    sourceFormat: MediaTranscoding.subtitles(codec: "srt", isExternal: true)
                ),
            ],
            selectedAudioID: "audio",
            selectedSubtitleID: nil,
            defaultVideoTranscoding: nil,
            defaultAudioTranscoding: nil,
            sourceContainer: MediaTranscoding.container("mp4"),
            sourceVideo: MediaTranscoding.video(codec: "hevc", resolution: "4k", dynamicRange: "hdr10"),
            sourceAudio: MediaTranscoding.audio(codec: "eac3", channels: 6)
        )
    }
}
