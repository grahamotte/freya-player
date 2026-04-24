import AVFoundation

final class MediaPlayerLifecycle {
    private weak var player: AVPlayer?
    private var timeObserver: Any?
    private var timeControlObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var timelineTimer: Timer?
    private var onTimelineEvent: ((MediaPlaybackTimelineState, Int, Int?) -> Void)?
    private var onPlaybackEnded: ((Int, Int?) -> Void)?
    private var lastState: MediaPlaybackTimelineState?
    private var didSeekInitialPosition = false

    func bind(
        to player: AVPlayer,
        resumeOffsetMilliseconds: Int?,
        onTimelineEvent: @escaping (MediaPlaybackTimelineState, Int, Int?) -> Void,
        onPlaybackEnded: @escaping (Int, Int?) -> Void
    ) {
        guard self.player !== player else { return }

        unbind()
        self.player = player
        self.onTimelineEvent = onTimelineEvent
        self.onPlaybackEnded = onPlaybackEnded
        didSeekInitialPosition = resumeOffsetMilliseconds == nil

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 10, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            self?.sendCurrentTimeline()
        }

        bindResumePosition(resumeOffsetMilliseconds, to: player)
        observePlaybackState(of: player)
        observePlaybackEnd(of: player)
    }

    func unbind() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }

        timelineTimer?.invalidate()
        timeObserver = nil
        timeControlObservation = nil
        itemStatusObservation = nil
        endObserver = nil
        timelineTimer = nil
        player = nil
        onTimelineEvent = nil
        onPlaybackEnded = nil
        lastState = nil
        didSeekInitialPosition = false
    }

    private func bindResumePosition(_ resumeOffsetMilliseconds: Int?, to player: AVPlayer) {
        guard let item = player.currentItem, let resumeOffsetMilliseconds, resumeOffsetMilliseconds > 0 else {
            didSeekInitialPosition = true
            return
        }

        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self, !self.didSeekInitialPosition, item.status == .readyToPlay else { return }
            self.didSeekInitialPosition = true
            player.seek(
                to: CMTime(milliseconds: resumeOffsetMilliseconds),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            )
        }
    }

    private func observePlaybackState(of player: AVPlayer) {
        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            self?.sendState(for: player)
        }
    }

    private func observePlaybackEnd(of player: AVPlayer) {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            let time = player.currentItem?.duration.milliseconds ?? player.currentTime().milliseconds ?? 0
            let duration = player.currentItem?.duration.milliseconds
            self?.onPlaybackEnded?(time, duration)
        }
    }

    private func sendCurrentTimeline() {
        guard let player else { return }
        onTimelineEvent?(
            state(for: player),
            player.currentTime().milliseconds ?? 0,
            player.currentItem?.duration.milliseconds
        )
    }

    private func sendState(for player: AVPlayer) {
        let state = state(for: player)
        updateTimelineTimer(for: state)
        guard state != lastState else { return }
        lastState = state
        onTimelineEvent?(
            state,
            player.currentTime().milliseconds ?? 0,
            player.currentItem?.duration.milliseconds
        )
    }

    private func updateTimelineTimer(for state: MediaPlaybackTimelineState) {
        guard state == .paused || state == .buffering else {
            timelineTimer?.invalidate()
            timelineTimer = nil
            return
        }

        guard timelineTimer == nil else { return }

        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            self?.sendCurrentTimeline()
        }
        RunLoop.main.add(timer, forMode: .common)
        timelineTimer = timer
    }

    private func state(for player: AVPlayer) -> MediaPlaybackTimelineState {
        switch player.timeControlStatus {
        case .paused:
            return .paused
        case .waitingToPlayAtSpecifiedRate:
            return .buffering
        case .playing:
            return .playing
        @unknown default:
            return .paused
        }
    }
}

extension CMTime {
    init(milliseconds: Int) {
        self.init(seconds: Double(milliseconds) / 1000, preferredTimescale: 600)
    }

    var milliseconds: Int? {
        guard isNumeric && seconds.isFinite else { return nil }
        return max(Int((seconds * 1000).rounded()), 0)
    }
}
