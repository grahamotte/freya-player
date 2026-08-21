import XCTest
@testable import FreyaPlayerCore

final class PlaybackResumeProbeTests: XCTestCase {
    func testMonitorsPlaybackWithinTheOriginalBuffer() {
        var probe = PlaybackResumeProbe(initialBufferedThroughMilliseconds: 120_000)

        XCTAssertEqual(
            probe.decision(
                state: .playing,
                currentTimeMilliseconds: 100_000,
                bufferedThroughMilliseconds: 120_000
            ),
            .monitoring
        )
    }

    func testRecognizesNewBufferedMedia() {
        var probe = PlaybackResumeProbe(initialBufferedThroughMilliseconds: 120_000)

        XCTAssertEqual(
            probe.decision(
                state: .playing,
                currentTimeMilliseconds: 105_000,
                bufferedThroughMilliseconds: 121_000
            ),
            .recovered
        )
    }

    func testRecognizesPlaybackBeyondTheOriginalBuffer() {
        var probe = PlaybackResumeProbe(initialBufferedThroughMilliseconds: 120_000)

        XCTAssertEqual(
            probe.decision(
                state: .playing,
                currentTimeMilliseconds: 120_001,
                bufferedThroughMilliseconds: nil
            ),
            .recovered
        )
    }

    func testRestartsAfterTheGracePeriodWhenPlaybackExhaustsTheOriginalBuffer() {
        var probe = PlaybackResumeProbe(initialBufferedThroughMilliseconds: 120_000)
        let bufferEdgeReachedAt = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(
            probe.decision(
                state: .buffering,
                currentTimeMilliseconds: 119_500,
                bufferedThroughMilliseconds: 120_000,
                at: bufferEdgeReachedAt
            ),
            .waitingAtBufferEdge
        )
        XCTAssertEqual(
            probe.decision(
                state: .buffering,
                currentTimeMilliseconds: 119_500,
                bufferedThroughMilliseconds: 120_000,
                at: bufferEdgeReachedAt.addingTimeInterval(
                    PlaybackResumeProbe.bufferEdgeGraceInterval
                )
            ),
            .restart
        )
    }

    func testRestartsAfterTheGracePeriodWhenNavigationStartsBeyondTheBuffer() {
        let navigationTime = Date(timeIntervalSince1970: 1_000)
        var probe = PlaybackResumeProbe(
            initialBufferedThroughMilliseconds: nil,
            startsAtBufferEdge: true,
            at: navigationTime
        )

        XCTAssertEqual(
            probe.decision(
                state: .buffering,
                currentTimeMilliseconds: 150_000,
                bufferedThroughMilliseconds: nil,
                at: navigationTime.addingTimeInterval(
                    PlaybackResumeProbe.bufferEdgeGraceInterval
                )
            ),
            .restart
        )
    }

    func testNavigationGracePeriodSurvivesASeekPause() {
        let navigationTime = Date(timeIntervalSince1970: 1_000)
        var probe = PlaybackResumeProbe(
            initialBufferedThroughMilliseconds: nil,
            startsAtBufferEdge: true,
            at: navigationTime
        )

        XCTAssertEqual(
            probe.decision(
                state: .paused,
                currentTimeMilliseconds: 100_000,
                bufferedThroughMilliseconds: nil,
                at: navigationTime.addingTimeInterval(1)
            ),
            .monitoring
        )
        XCTAssertEqual(
            probe.decision(
                state: .buffering,
                currentTimeMilliseconds: 150_000,
                bufferedThroughMilliseconds: nil,
                at: navigationTime.addingTimeInterval(
                    PlaybackResumeProbe.bufferEdgeGraceInterval
                )
            ),
            .restart
        )
    }

    func testWaitsWhenBufferingStartsWithMediaStillAvailable() {
        var probe = PlaybackResumeProbe(initialBufferedThroughMilliseconds: 120_000)

        XCTAssertEqual(
            probe.decision(
                state: .buffering,
                currentTimeMilliseconds: 100_000,
                bufferedThroughMilliseconds: 120_000
            ),
            .monitoring
        )
    }

    func testHandlesAnInitiallyUnknownBufferRange() {
        var probe = PlaybackResumeProbe(initialBufferedThroughMilliseconds: nil)
        let bufferEdgeReachedAt = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(
            probe.decision(
                state: .playing,
                currentTimeMilliseconds: 100_000,
                bufferedThroughMilliseconds: 110_000
            ),
            .recovered
        )
        XCTAssertEqual(
            probe.decision(
                state: .buffering,
                currentTimeMilliseconds: 100_000,
                bufferedThroughMilliseconds: nil,
                at: bufferEdgeReachedAt
            ),
            .waitingAtBufferEdge
        )
        XCTAssertEqual(
            probe.decision(
                state: .buffering,
                currentTimeMilliseconds: 100_000,
                bufferedThroughMilliseconds: nil,
                at: bufferEdgeReachedAt.addingTimeInterval(
                    PlaybackResumeProbe.bufferEdgeGraceInterval
                )
            ),
            .restart
        )
    }

    func testClearsTheGracePeriodWhenPlaybackResumes() {
        var probe = PlaybackResumeProbe(initialBufferedThroughMilliseconds: 120_000)
        let firstBufferEdgeReachedAt = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(
            probe.decision(
                state: .buffering,
                currentTimeMilliseconds: 119_500,
                bufferedThroughMilliseconds: 120_000,
                at: firstBufferEdgeReachedAt
            ),
            .waitingAtBufferEdge
        )
        XCTAssertEqual(
            probe.decision(
                state: .playing,
                currentTimeMilliseconds: 119_500,
                bufferedThroughMilliseconds: 120_000,
                at: firstBufferEdgeReachedAt.addingTimeInterval(1)
            ),
            .monitoring
        )
        XCTAssertEqual(
            probe.decision(
                state: .buffering,
                currentTimeMilliseconds: 119_500,
                bufferedThroughMilliseconds: 120_000,
                at: firstBufferEdgeReachedAt.addingTimeInterval(4)
            ),
            .waitingAtBufferEdge
        )
    }
}
