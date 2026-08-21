import AVFoundation
import OSLog

final class PlaybackSessionController {
    let player = AVPlayer()

    private var timeObserver: Any?
    private var timeControlObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?
    private var stalledObserver: NSObjectProtocol?
    private var accessLogObserver: NSObjectProtocol?
    private var timelineTimer: Timer?
    private var navigationTimer: Timer?
    private var stallTimer: Timer?
    private var resumeProbeTimer: Timer?
    private var onTimelineEvent: ((MediaPlaybackTimelineState, Int, Int?) -> Void)?
    private var onPlaybackEnded: ((Int, Int?) -> Void)?
    private var onRecoveryNeeded: ((Int, Error?) -> Void)?
    private var onNavigationNeeded: ((Int) -> Void)?
    private var lastState: MediaPlaybackTimelineState?
    private var startOffsetMilliseconds: Int?
    private var enableSubtitles = false
    private var shouldPlayWhenReady = false
    private var didPrepareCurrentItem = false
    private var canSendTimelineEvents = false
    private var didRequestRecovery = false
    private var recoveryOffsetMilliseconds = 0
    private var pendingNavigationOffsetMilliseconds: Int?
    private var didObservePause = false
    private var resumeProbe: PlaybackResumeProbe?
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "FreyaPlayer",
        category: "Playback"
    )

    init() {
        observePlaybackState()
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            self?.sendCurrentTimeline()
        }
    }

    deinit {
        teardown()
    }

    func load(
        item: AVPlayerItem,
        startOffsetMilliseconds: Int? = nil,
        enableSubtitles: Bool = false,
        autoplay: Bool = true,
        onTimelineEvent: @escaping (MediaPlaybackTimelineState, Int, Int?) -> Void,
        onPlaybackEnded: @escaping (Int, Int?) -> Void,
        onRecoveryNeeded: @escaping (Int, Error?) -> Void = { _, _ in },
        onNavigationNeeded: ((Int) -> Void)? = nil
    ) {
        PlaybackAudioSession.activate()
        unbindCurrentItem()

        self.startOffsetMilliseconds = startOffsetMilliseconds.flatMap { $0 > 0 ? $0 : nil }
        self.enableSubtitles = enableSubtitles
        self.shouldPlayWhenReady = autoplay
        self.onTimelineEvent = onTimelineEvent
        self.onPlaybackEnded = onPlaybackEnded
        self.onRecoveryNeeded = onRecoveryNeeded
        self.onNavigationNeeded = onNavigationNeeded
        didPrepareCurrentItem = false
        canSendTimelineEvents = false
        didRequestRecovery = false
        recoveryOffsetMilliseconds = self.startOffsetMilliseconds ?? 0
        pendingNavigationOffsetMilliseconds = nil
        didObservePause = false
        resumeProbe = nil
        lastState = nil

        player.replaceCurrentItem(with: item)
        observeItemStatus(item)
        observePlaybackEnd(item)
        observePlaybackFailure(item)
        observeDiagnostics(item)
    }

    func play() {
        PlaybackAudioSession.activate()
        shouldPlayWhenReady = true
        guard didPrepareCurrentItem else { return }
        player.play()
    }

    func pause() {
        shouldPlayWhenReady = false
        player.pause()
    }

    func stop() {
        pause()
        teardown()
        PlaybackAudioSession.deactivate()
    }

    func prepareForRecovery() {
        rememberCurrentTime()
        shouldPlayWhenReady = false
        unbindCurrentItem()
        player.replaceCurrentItem(with: nil)
        didPrepareCurrentItem = false
        canSendTimelineEvents = false
    }

    func teardown() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        timeControlObservation = nil
        unbindCurrentItem()
        player.replaceCurrentItem(with: nil)
        onTimelineEvent = nil
        onPlaybackEnded = nil
        onRecoveryNeeded = nil
        onNavigationNeeded = nil
        lastState = nil
        shouldPlayWhenReady = false
        didPrepareCurrentItem = false
        canSendTimelineEvents = false
    }

    var currentTimeMilliseconds: Int {
        player.currentTime().milliseconds ?? 0
    }

    var durationMilliseconds: Int? {
        player.currentItem?.duration.milliseconds
    }

    func userNavigated(to time: CMTime) {
        guard let offset = time.milliseconds else { return }
        pendingNavigationOffsetMilliseconds = offset
        guard onNavigationNeeded != nil else { return }

        navigationTimer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self, let offset = self.pendingNavigationOffsetMilliseconds else { return }
            self.navigationTimer = nil
            self.onNavigationNeeded?(offset)
        }
        RunLoop.main.add(timer, forMode: .common)
        navigationTimer = timer
    }

    private func unbindCurrentItem() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
        }
        if let stalledObserver {
            NotificationCenter.default.removeObserver(stalledObserver)
        }
        if let accessLogObserver {
            NotificationCenter.default.removeObserver(accessLogObserver)
        }
        itemStatusObservation = nil
        endObserver = nil
        failureObserver = nil
        stalledObserver = nil
        accessLogObserver = nil
        timelineTimer?.invalidate()
        navigationTimer?.invalidate()
        stallTimer?.invalidate()
        resumeProbeTimer?.invalidate()
        timelineTimer = nil
        navigationTimer = nil
        stallTimer = nil
        resumeProbeTimer = nil
    }

    private func observeItemStatus(_ item: AVPlayerItem) {
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }
            switch item.status {
            case .readyToPlay where !self.didPrepareCurrentItem:
                self.prepareItemForPlayback(item)
            case .failed:
                self.logger.error("item failed: \(item.error?.localizedDescription ?? "unknown", privacy: .public)")
                self.requestRecovery(error: item.error)
            default:
                break
            }
        }
    }

    private func prepareItemForPlayback(_ item: AVPlayerItem) {
        didPrepareCurrentItem = true
        enableSubtitlesIfNeeded(on: item)

        guard let startOffsetMilliseconds else {
            canSendTimelineEvents = true
            if shouldPlayWhenReady { player.play() }
            sendState()
            return
        }

        let duration = item.duration.milliseconds
        let offset = min(startOffsetMilliseconds, max((duration ?? .max) - 10_000, 0))
        let tolerance = CMTime(seconds: 5, preferredTimescale: 600)
        player.seek(
            to: CMTime(milliseconds: offset),
            toleranceBefore: tolerance,
            toleranceAfter: tolerance
        ) { [weak self, weak item] _ in
            guard let item, self?.player.currentItem === item else { return }
            guard let self else { return }
            self.canSendTimelineEvents = true
            if self.shouldPlayWhenReady { self.player.play() }
            self.sendState()
        }
    }

    private func enableSubtitlesIfNeeded(on item: AVPlayerItem) {
        guard enableSubtitles else { return }
        Task { [weak self, weak item] in
            guard let self, let item,
                  let group = try? await item.asset.loadMediaSelectionGroup(for: .legible),
                  let option = group.defaultOption ?? group.options.first,
                  self.player.currentItem === item else { return }
            item.select(option, in: group)
        }
    }

    private func observePlaybackState() {
        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] _, _ in
            self?.sendState()
        }
    }

    private func observePlaybackEnd(_ item: AVPlayerItem) {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.onPlaybackEnded?(
                item.duration.milliseconds ?? self?.currentTimeMilliseconds ?? 0,
                item.duration.milliseconds
            )
        }
    }

    private func observePlaybackFailure(_ item: AVPlayerItem) {
        failureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error ?? item.error
            self?.logger.error("playback failed: \(error?.localizedDescription ?? "unknown", privacy: .public)")
            self?.requestRecovery(error: error)
        }
    }

    private func observeDiagnostics(_ item: AVPlayerItem) {
        stalledObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.logger.warning("playback stalled at \(self?.currentTimeMilliseconds ?? 0)ms")
        }

        accessLogObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemNewAccessLogEntry,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let event = item.accessLog()?.events.last else { return }
            self?.logger.info(
                "access observed=\(event.observedBitrate / 1_000)kbps indicated=\(event.indicatedBitrate / 1_000)kbps stalls=\(event.numberOfStalls)"
            )
        }
    }

    private func sendCurrentTimeline() {
        guard canSendTimelineEvents else { return }
        rememberCurrentTime()
        let state = state()
        if shouldRestartAfterResume(state) { return }
        onTimelineEvent?(state, currentTimeMilliseconds, durationMilliseconds)
    }

    private func sendState() {
        guard canSendTimelineEvents else { return }
        let state = state()
        if state == .playing, onNavigationNeeded == nil {
            pendingNavigationOffsetMilliseconds = nil
        }
        if state != .paused { rememberCurrentTime() }
        if didResumeAfterPause(state) {
            resumeProbe = PlaybackResumeProbe(
                initialBufferedThroughMilliseconds: bufferedThroughMilliseconds
            )
        }
        if shouldRestartAfterResume(state) { return }
        updateTimelineTimer(for: state)
        updateStallTimer(for: state)
        guard state != lastState else { return }
        lastState = state
        logger.debug(
            "state=\(state.rawValue, privacy: .public) reason=\(self.player.reasonForWaitingToPlay?.rawValue ?? "none", privacy: .public)"
        )
        onTimelineEvent?(state, currentTimeMilliseconds, durationMilliseconds)
    }

    private func didResumeAfterPause(_ state: MediaPlaybackTimelineState) -> Bool {
        guard state != .paused else {
            didObservePause = true
            resumeProbe = nil
            resumeProbeTimer?.invalidate()
            resumeProbeTimer = nil
            return false
        }

        defer { didObservePause = false }
        return didObservePause
    }

    private func shouldRestartAfterResume(_ state: MediaPlaybackTimelineState) -> Bool {
        guard var resumeProbe else { return false }
        let decision = resumeProbe.decision(
            state: state,
            currentTimeMilliseconds: currentTimeMilliseconds,
            bufferedThroughMilliseconds: bufferedThroughMilliseconds
        )
        self.resumeProbe = resumeProbe
        switch decision {
        case .monitoring:
            resumeProbeTimer?.invalidate()
            resumeProbeTimer = nil
            return false
        case .recovered:
            finishResumeProbe()
            return false
        case .waitingAtBufferEdge:
            scheduleResumeProbeTimer()
            return false
        case .restart:
            finishResumeProbe()
            requestRecovery()
            return true
        }
    }

    private func scheduleResumeProbeTimer() {
        guard resumeProbeTimer == nil else { return }
        let timer = Timer(
            timeInterval: PlaybackResumeProbe.bufferEdgeGraceInterval,
            repeats: false
        ) { [weak self] _ in
            self?.resumeProbeTimer = nil
            self?.sendState()
        }
        RunLoop.main.add(timer, forMode: .common)
        resumeProbeTimer = timer
    }

    private func finishResumeProbe() {
        resumeProbeTimer?.invalidate()
        resumeProbeTimer = nil
        resumeProbe = nil
    }

    private var bufferedThroughMilliseconds: Int? {
        guard let item = player.currentItem else { return nil }
        let currentTime = player.currentTime().seconds
        guard currentTime.isFinite else { return nil }

        return item.loadedTimeRanges
            .map(\.timeRangeValue)
            .filter { range in
                let start = range.start.seconds
                let end = CMTimeRangeGetEnd(range).seconds
                return start.isFinite
                    && end.isFinite
                    && start <= currentTime + 0.5
                    && end >= currentTime - 0.5
            }
            .compactMap { CMTimeRangeGetEnd($0).milliseconds }
            .max()
    }

    private func requestRecovery(error: Error? = nil) {
        guard !didRequestRecovery else { return }
        didRequestRecovery = true
        player.pause()
        onRecoveryNeeded?(pendingNavigationOffsetMilliseconds ?? recoveryOffsetMilliseconds, error)
    }

    private func rememberCurrentTime() {
        let time = currentTimeMilliseconds
        guard time > 0 else { return }
        recoveryOffsetMilliseconds = time
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

    private func updateStallTimer(for state: MediaPlaybackTimelineState) {
        guard state == .buffering, shouldPlayWhenReady else {
            stallTimer?.invalidate()
            stallTimer = nil
            return
        }

        guard stallTimer == nil else { return }
        let offset = currentTimeMilliseconds
        let timer = Timer(timeInterval: 30, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.stallTimer = nil
            guard self.player.timeControlStatus == .waitingToPlayAtSpecifiedRate else { return }
            guard self.currentTimeMilliseconds <= offset + 1_000 else {
                self.updateStallTimer(for: .buffering)
                return
            }
            self.logger.error("playback stalled for 30s at \(offset)ms")
            self.requestRecovery()
        }
        RunLoop.main.add(timer, forMode: .common)
        stallTimer = timer
    }

    private func state() -> MediaPlaybackTimelineState {
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
