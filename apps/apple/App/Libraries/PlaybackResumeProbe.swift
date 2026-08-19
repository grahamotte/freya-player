import Foundation

enum PlaybackResumeProbeDecision: Equatable {
    case monitoring
    case recovered
    case waitingAtBufferEdge
    case restart
}

struct PlaybackResumeProbe {
    static let bufferEdgeGraceInterval: TimeInterval = 3

    private static let bufferGrowthMilliseconds = 1_000
    private static let exhaustedBufferMilliseconds = 1_000

    let initialBufferedThroughMilliseconds: Int?
    private var bufferEdgeReachedAt: Date?

    init(initialBufferedThroughMilliseconds: Int?) {
        self.initialBufferedThroughMilliseconds = initialBufferedThroughMilliseconds
    }

    mutating func decision(
        state: MediaPlaybackTimelineState,
        currentTimeMilliseconds: Int,
        bufferedThroughMilliseconds: Int?,
        at date: Date = Date()
    ) -> PlaybackResumeProbeDecision {
        if let initialBufferedThroughMilliseconds {
            if let bufferedThroughMilliseconds,
               bufferedThroughMilliseconds >= initialBufferedThroughMilliseconds + Self.bufferGrowthMilliseconds {
                return .recovered
            }
            if currentTimeMilliseconds > initialBufferedThroughMilliseconds {
                return .recovered
            }
        } else if bufferedThroughMilliseconds != nil {
            return .recovered
        }

        guard state == .buffering else {
            bufferEdgeReachedAt = nil
            return .monitoring
        }
        let bufferedTimeRemaining = bufferedThroughMilliseconds.map {
            max($0 - currentTimeMilliseconds, 0)
        } ?? 0
        guard bufferedTimeRemaining <= Self.exhaustedBufferMilliseconds else {
            bufferEdgeReachedAt = nil
            return .monitoring
        }
        guard let bufferEdgeReachedAt else {
            self.bufferEdgeReachedAt = date
            return .waitingAtBufferEdge
        }
        return date.timeIntervalSince(bufferEdgeReachedAt) >= Self.bufferEdgeGraceInterval
            ? .restart
            : .waitingAtBufferEdge
    }
}
