import AVFoundation
import OSLog

final class PlaybackSessionController {
    private(set) var player = AVPlayer()

    private var timeObserver: Any?
    private var timeControlObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var pendingPlayerStatusObservation: NSKeyValueObservation?
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
    private var onPlayerChanged: ((AVPlayer) -> Void)?
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
    private var didObservePlaying = false
    private var isPreparingItem = false
    private var pendingItem: AVPlayerItem?
    private var pendingPlayer: AVPlayer?
    private var pendingOffsetMilliseconds: Int?
    private var resumeProbe: PlaybackResumeProbe?
    private var resumeProbeFollowsNavigation = false
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "FreyaPlayer",
        category: "Playback"
    )

    init() {
        bindPlayerObservers()
    }

    deinit {
        teardown()
    }

    func load(
        item: AVPlayerItem,
        startOffsetMilliseconds: Int? = nil,
        timelineOffsetMilliseconds: Int? = nil,
        enableSubtitles: Bool = false,
        autoplay: Bool = true,
        onTimelineEvent: @escaping (MediaPlaybackTimelineState, Int, Int?) -> Void,
        onPlaybackEnded: @escaping (Int, Int?) -> Void,
        onRecoveryNeeded: @escaping (Int, Error?) -> Void = { _, _ in },
        onNavigationNeeded: ((Int) -> Void)? = nil
    ) {
        PlaybackAudioSession.activate()
        let currentItem = player.currentItem
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
        recoveryOffsetMilliseconds = timelineOffsetMilliseconds ?? self.startOffsetMilliseconds ?? 0
        pendingNavigationOffsetMilliseconds = nil
        didObservePause = false
        didObservePlaying = false
        isPreparingItem = false
        resumeProbe = nil
        resumeProbeFollowsNavigation = false
        lastState = nil

        guard currentItem != nil else {
            attach(item)
            return
        }

        pendingItem = item
        pendingOffsetMilliseconds = self.startOffsetMilliseconds
        let pendingPlayer = AVPlayer(playerItem: item)
        self.pendingPlayer = pendingPlayer
        observeItemStatus(item)
        observePendingPlayerStatus(pendingPlayer, item: item)
    }

    func setPlayerChangeHandler(_ handler: ((AVPlayer) -> Void)?) {
        onPlayerChanged = handler
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

    @discardableResult
    func prepareForRecovery() -> Bool {
        rememberCurrentTime()
        let autoplay = shouldPlayWhenReady
        canSendTimelineEvents = false
        unbindCurrentItem()
        didPrepareCurrentItem = false
        if !autoplay {
            player.pause()
        }
        return autoplay
    }

    func teardown() {
        unbindPlayerObservers()
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

    @discardableResult
    func userNavigated(to time: CMTime) -> Bool {
        guard let offset = time.milliseconds else { return false }
        pendingNavigationOffsetMilliseconds = offset
        guard onNavigationNeeded != nil else {
            let bufferedThroughMilliseconds = bufferedThroughMilliseconds(at: offset)
            resumeProbeTimer?.invalidate()
            resumeProbeTimer = nil
            resumeProbe = PlaybackResumeProbe(
                initialBufferedThroughMilliseconds: bufferedThroughMilliseconds,
                startsAtBufferEdge: bufferedThroughMilliseconds == nil
            )
            resumeProbeFollowsNavigation = true
            if bufferedThroughMilliseconds == nil {
                scheduleResumeProbeTimer()
            }
            return false
        }

        navigationTimer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self, let offset = self.pendingNavigationOffsetMilliseconds else { return }
            self.navigationTimer = nil
            self.onNavigationNeeded?(offset)
        }
        RunLoop.main.add(timer, forMode: .common)
        navigationTimer = timer
        return true
    }

    func userWillResumeAfterNavigation() {
        shouldPlayWhenReady = true
    }

    private func attach(_ item: AVPlayerItem) {
        player.replaceCurrentItem(with: item)
        observeItemStatus(item)
        observePlaybackEnd(item)
        observePlaybackFailure(item)
        observeDiagnostics(item)
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
        pendingItem?.cancelPendingSeeks()
        pendingPlayer?.replaceCurrentItem(with: nil)
        pendingPlayerStatusObservation = nil
        pendingItem = nil
        pendingPlayer = nil
        pendingOffsetMilliseconds = nil
        isPreparingItem = false
    }

    private func observeItemStatus(_ item: AVPlayerItem) {
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }
            switch item.status {
            case .readyToPlay:
                self.prepareItemForPlayback(item)
            case .failed:
                self.logger.error("item failed: \(item.error?.localizedDescription ?? "unknown", privacy: .public)")
                self.requestRecovery(error: item.error)
            default:
                break
            }
        }
    }

    private func observePendingPlayerStatus(_ pendingPlayer: AVPlayer, item: AVPlayerItem) {
        pendingPlayerStatusObservation = pendingPlayer.observe(\.status, options: [.initial, .new]) {
            [weak self, weak item] pendingPlayer, _ in
            guard let self, let item else { return }
            switch pendingPlayer.status {
            case .readyToPlay:
                self.prepareItemForPlayback(item)
            case .failed:
                self.requestRecovery(error: pendingPlayer.error)
            default:
                break
            }
        }
    }

    private func prepareItemForPlayback(_ item: AVPlayerItem) {
        guard !isPreparingItem else { return }
        if let pendingPlayer, pendingItem === item {
            guard item.status == .readyToPlay, pendingPlayer.status == .readyToPlay else { return }
            isPreparingItem = true
            enableSubtitlesIfNeeded(on: item)
            seek(
                pendingPlayer,
                item: item,
                to: pendingOffsetMilliseconds
            ) { [weak self, weak item, weak pendingPlayer] in
                guard let self, let item, let pendingPlayer,
                      self.pendingItem === item,
                      self.pendingPlayer === pendingPlayer else { return }
                self.activatePendingPlayer(pendingPlayer, item: item)
            }
            return
        }

        guard player.currentItem === item, !didPrepareCurrentItem else { return }
        isPreparingItem = true
        enableSubtitlesIfNeeded(on: item)
        seek(player, item: item, to: startOffsetMilliseconds) { [weak self, weak item] in
            guard let self, let item else { return }
            self.activatePreparedItem(item)
        }
    }

    private func seek(
        _ player: AVPlayer,
        item: AVPlayerItem,
        to offsetMilliseconds: Int?,
        completion: @escaping () -> Void
    ) {
        guard let offsetMilliseconds else {
            completion()
            return
        }
        let duration = item.duration.milliseconds
        let offset = min(offsetMilliseconds, max((duration ?? .max) - 10_000, 0))
        let tolerance = CMTime(seconds: 5, preferredTimescale: 600)
        player.seek(
            to: CMTime(milliseconds: offset),
            toleranceBefore: tolerance,
            toleranceAfter: tolerance
        ) { _ in completion() }
    }

    private func activatePendingPlayer(_ pendingPlayer: AVPlayer, item: AVPlayerItem) {
        let previousPlayer = player
        unbindPlayerObservers()
        player = pendingPlayer
        self.pendingPlayer = nil
        pendingItem = nil
        pendingOffsetMilliseconds = nil
        pendingPlayerStatusObservation = nil
        bindPlayerObservers()
        observePlaybackEnd(item)
        observePlaybackFailure(item)
        observeDiagnostics(item)
        didPrepareCurrentItem = true
        isPreparingItem = false
        canSendTimelineEvents = true
        if shouldPlayWhenReady { pendingPlayer.play() }
        onPlayerChanged?(pendingPlayer)
        previousPlayer.pause()
        previousPlayer.replaceCurrentItem(with: nil)
        sendState()
    }

    private func activatePreparedItem(_ item: AVPlayerItem) {
        guard player.currentItem === item else { return }
        didPrepareCurrentItem = true
        isPreparingItem = false
        canSendTimelineEvents = true
        if shouldPlayWhenReady { player.play() }
        sendState()
    }

    private func enableSubtitlesIfNeeded(on item: AVPlayerItem) {
        guard enableSubtitles else { return }
        Task { [weak self, weak item] in
            guard let self, let item,
                  let group = try? await item.asset.loadMediaSelectionGroup(for: .legible),
                  let option = group.defaultOption ?? group.options.first,
                  self.player.currentItem === item || self.pendingItem === item else { return }
            item.select(option, in: group)
        }
    }

    private func bindPlayerObservers() {
        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] _, _ in
            self?.sendState()
        }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            self?.sendCurrentTimeline()
        }
    }

    private func unbindPlayerObservers() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        timeControlObservation = nil
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
        if state != .paused { rememberCurrentTime() }
        if didResumeAfterPause(state), !resumeProbeFollowsNavigation {
            resumeProbe = PlaybackResumeProbe(
                initialBufferedThroughMilliseconds: bufferedThroughMilliseconds
            )
        }
        if state == .buffering,
           shouldPlayWhenReady,
           didObservePlaying,
           resumeProbe == nil {
            resumeProbe = PlaybackResumeProbe(
                initialBufferedThroughMilliseconds: bufferedThroughMilliseconds
            )
        }
        if shouldRestartAfterResume(state) { return }
        if state == .playing {
            didObservePlaying = true
        }
        if state == .playing, onNavigationNeeded == nil {
            pendingNavigationOffsetMilliseconds = nil
        }
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
            if !resumeProbeFollowsNavigation {
                finishResumeProbe()
            }
            return false
        }

        defer { didObservePause = false }
        return didObservePause
    }

    private func shouldRestartAfterResume(_ state: MediaPlaybackTimelineState) -> Bool {
        guard var resumeProbe else { return false }
        let probeTimeMilliseconds = resumeProbeFollowsNavigation
            ? pendingNavigationOffsetMilliseconds ?? currentTimeMilliseconds
            : currentTimeMilliseconds
        let bufferedThroughMilliseconds = resumeProbeFollowsNavigation
            ? bufferedThroughMilliseconds(at: probeTimeMilliseconds)
            : bufferedThroughMilliseconds
        let decision = resumeProbe.decision(
            state: state,
            currentTimeMilliseconds: probeTimeMilliseconds,
            bufferedThroughMilliseconds: bufferedThroughMilliseconds
        )
        self.resumeProbe = resumeProbe
        switch decision {
        case .monitoring:
            if resumeProbeFollowsNavigation,
               state == .playing,
               bufferedThroughMilliseconds != nil {
                resumeProbeFollowsNavigation = false
            }
            guard !resumeProbeFollowsNavigation else { return false }
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
        resumeProbeFollowsNavigation = false
    }

    private var bufferedThroughMilliseconds: Int? {
        bufferedThroughMilliseconds(at: currentTimeMilliseconds)
    }

    private func bufferedThroughMilliseconds(at timeMilliseconds: Int) -> Int? {
        guard let item = player.currentItem else { return nil }
        let time = Double(timeMilliseconds) / 1_000

        return item.loadedTimeRanges
            .map(\.timeRangeValue)
            .filter { range in
                let start = range.start.seconds
                let end = CMTimeRangeGetEnd(range).seconds
                return start.isFinite
                    && end.isFinite
                    && start <= time + 0.5
                    && end >= time - 0.5
            }
            .compactMap { CMTimeRangeGetEnd($0).milliseconds }
            .max()
    }

    private func requestRecovery(error: Error? = nil) {
        guard !didRequestRecovery else { return }
        didRequestRecovery = true
        if !shouldPlayWhenReady {
            player.pause()
        }
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
