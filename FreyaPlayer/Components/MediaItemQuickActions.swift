import AVKit
import UIKit

#if os(tvOS)
@MainActor
final class MediaItemQuickActionHandler {
    private weak var presenter: UIViewController?
    private let model: AppModel
    private let focusedItem: () -> MediaItem?
    private let setOptimisticWatchStatus: (String, Bool) -> Void
    private let clearOptimisticWatchStatus: (String) -> Void
    private let refresh: () async -> Void

    private var pressTask: Task<Void, Never>?
    private var didHandleLongPress = false
    private var presentedPlayerController: QuickPlayPlayerViewController?

    init(
        presenter: UIViewController,
        model: AppModel,
        focusedItem: @escaping () -> MediaItem?,
        setOptimisticWatchStatus: @escaping (String, Bool) -> Void,
        clearOptimisticWatchStatus: @escaping (String) -> Void,
        refresh: @escaping () async -> Void
    ) {
        self.presenter = presenter
        self.model = model
        self.focusedItem = focusedItem
        self.setOptimisticWatchStatus = setOptimisticWatchStatus
        self.clearOptimisticWatchStatus = clearOptimisticWatchStatus
        self.refresh = refresh
    }

    func pressesBegan(_ presses: Set<UIPress>) {
        guard presses.contains(where: { $0.type == .select }), let item = focusedItem() else { return }

        didHandleLongPress = false
        pressTask?.cancel()
        pressTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.presentQuickActions(for: item)
            }
        }
    }

    func pressesEnded(_ presses: Set<UIPress>) -> Bool {
        guard presses.contains(where: { $0.type == .select }) else { return false }

        pressTask?.cancel()
        pressTask = nil

        if didHandleLongPress {
            didHandleLongPress = false
            return true
        }

        return false
    }

    func pressesCancelled(_ presses: Set<UIPress>) {
        guard presses.contains(where: { $0.type == .select }) else { return }

        pressTask?.cancel()
        pressTask = nil
        didHandleLongPress = false
    }

    private func presentQuickActions(for item: MediaItem) {
        guard let presenter, presenter.presentedViewController == nil else { return }

        didHandleLongPress = true

        let alert = UIAlertController(title: item.title, message: nil, preferredStyle: .alert)
        let canMarkUnwatched = item.isWatched || (item.progress ?? 0) > 0 || (item.resumeOffsetMilliseconds ?? 0) > 0

        alert.addAction(UIAlertAction(title: "Play Now", style: .default) { [weak self] _ in
            Task { await self?.playNow(item) }
        })
        alert.addAction(UIAlertAction(title: "Mark Watched", style: .default) { [weak self] _ in
            Task { await self?.setWatchStatus(for: item, isWatched: true) }
        })
        if canMarkUnwatched {
            alert.addAction(UIAlertAction(title: "Mark Unwatched", style: .default) { [weak self] _ in
                Task { await self?.setWatchStatus(for: item, isWatched: false) }
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        presenter.present(alert, animated: true)
    }

    private func playNow(_ item: MediaItem) async {
        guard let presenter, let playbackID = item.playbackID else { return }

        do {
            let sessionID = UUID().uuidString
            let url = try await model.playbackURL(for: playbackID, sessionID: sessionID)
            let player = AVPlayer(url: url)
            let controller = QuickPlayPlayerViewController(
                player: player,
                resumeOffsetMilliseconds: item.resumeOffsetMilliseconds,
                onTimelineEvent: { [weak self] state, time, duration in
                    guard let self else { return }
                    Task {
                        await self.model.reportPlaybackTimeline(
                            for: playbackID,
                            state: state,
                            time: time,
                            duration: duration,
                            sessionID: sessionID
                        )
                    }
                },
                onPlaybackEnded: { [weak self] _, _ in
                    guard let self else { return }
                    Task {
                        await self.model.markPlaybackCompleted(for: playbackID)
                    }
                },
                onDismiss: { [weak self] player in
                    guard let self else { return }
                    self.presentedPlayerController = nil
                    let time = player.currentTime().milliseconds ?? 0
                    let duration = player.currentItem?.duration.milliseconds

                    Task {
                        await self.model.reportPlaybackTimeline(
                            for: playbackID,
                            state: .stopped,
                            time: time,
                            duration: duration,
                            sessionID: sessionID
                        )
                        await self.refresh()
                    }
                }
            )
            presentedPlayerController = controller
            presenter.present(controller, animated: true)
        } catch {
            presentActionError(message: "Playback isn't ready right now.")
        }
    }

    private func setWatchStatus(for item: MediaItem, isWatched: Bool) async {
        setOptimisticWatchStatus(item.id, isWatched)

        do {
            try await model.setWatchStatus(for: item, isWatched: isWatched)
            await refresh()
        } catch {
            clearOptimisticWatchStatus(item.id)
            presentActionError(message: "Couldn't update watch status.")
        }
    }

    private func presentActionError(message: String) {
        guard let presenter, presenter.presentedViewController == nil else { return }

        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter.present(alert, animated: true)
    }
}
#endif

final class QuickPlayPlayerViewController: AVPlayerViewController {
    private let managedPlayer: AVPlayer
    private let resumeOffsetMilliseconds: Int?
    private let onTimelineEvent: (MediaPlaybackTimelineState, Int, Int?) -> Void
    private let onPlaybackEnded: (Int, Int?) -> Void
    private let onDismiss: (AVPlayer) -> Void
    private let lifecycle = MediaPlayerLifecycle()

    private var didDismiss = false

    init(
        player: AVPlayer,
        resumeOffsetMilliseconds: Int?,
        onTimelineEvent: @escaping (MediaPlaybackTimelineState, Int, Int?) -> Void,
        onPlaybackEnded: @escaping (Int, Int?) -> Void,
        onDismiss: @escaping (AVPlayer) -> Void
    ) {
        managedPlayer = player
        self.resumeOffsetMilliseconds = resumeOffsetMilliseconds
        self.onTimelineEvent = onTimelineEvent
        self.onPlaybackEnded = onPlaybackEnded
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        player = managedPlayer
        lifecycle.bind(
            to: managedPlayer,
            resumeOffsetMilliseconds: resumeOffsetMilliseconds,
            onTimelineEvent: onTimelineEvent,
            onPlaybackEnded: onPlaybackEnded
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        managedPlayer.play()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        finishDismissalIfNeeded()
    }

    deinit {
        lifecycle.unbind()
    }

    private func finishDismissalIfNeeded() {
        guard !didDismiss else { return }
        didDismiss = true
        lifecycle.unbind()
        onDismiss(managedPlayer)
    }
}
