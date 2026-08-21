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
    private let startsAtBufferEdge: Bool
    private var bufferEdgeReachedAt: Date?

    init(
        initialBufferedThroughMilliseconds: Int?,
        startsAtBufferEdge: Bool = false,
        at date: Date = Date()
    ) {
        self.initialBufferedThroughMilliseconds = initialBufferedThroughMilliseconds
        self.startsAtBufferEdge = startsAtBufferEdge
        bufferEdgeReachedAt = startsAtBufferEdge ? date : nil
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
            if !startsAtBufferEdge {
                bufferEdgeReachedAt = nil
            }
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
