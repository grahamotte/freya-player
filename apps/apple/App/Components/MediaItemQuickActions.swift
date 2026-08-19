import AVKit
import SwiftUI
import UIKit

@MainActor
final class MediaItemQuickActionHandler {
    private weak var presenter: UIViewController?
    private let model: AppModel
    private let focusedItem: () -> MediaItem?

    private var pressTask: Task<Void, Never>?
    private var didHandleLongPress = false
    private var presentedPlayerController: StockPlayerViewController?

    init(
        presenter: UIViewController,
        model: AppModel,
        focusedItem: @escaping () -> MediaItem?
    ) {
        self.presenter = presenter
        self.model = model
        self.focusedItem = focusedItem
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
        let quickPlayTitle = model.cachedQuickPlayItem(for: item)?.quickPlayButtonTitle
            ?? item.quickPlayButtonTitle

        let playAction = UIAlertAction(title: quickPlayTitle, style: .default) { [weak self] _ in
            Task { await self?.playNow(item) }
        }
        playAction.isEnabled = !model.isOffline
        alert.addAction(playAction)
        let markSeenAction = UIAlertAction(title: MediaWatchStatusDisplay.markSeenTitle, style: .default) { [weak self] _ in
            self?.model.setWatchStatus(for: item, isWatched: true)
        }
        markSeenAction.isEnabled = !model.isOffline
        alert.addAction(markSeenAction)
        let markUnseenAction = UIAlertAction(title: MediaWatchStatusDisplay.markUnseenTitle, style: .default) { [weak self] _ in
            self?.model.setWatchStatus(for: item, isWatched: false)
        }
        markUnseenAction.isEnabled = !model.isOffline
        alert.addAction(markUnseenAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        presenter.present(alert, animated: true)
    }

    private func playNow(_ selectedItem: MediaItem) async {
        guard let item = await model.quickPlayItem(for: selectedItem),
              let playbackID = item.playbackID,
              let presenter,
              presenter.presentedViewController == nil else { return }

        do {
            let sessionID = UUID().uuidString
            let resource = try await model.playbackURL(
                for: playbackID,
                sessionID: sessionID,
                offsetMilliseconds: item.resumeOffsetMilliseconds
            )
            var activeSessionID = sessionID
            var activeRemoteSessionID = resource.remoteSessionID
            var seekTask: Task<Void, Never>?
            var recoveryTask: Task<Void, Never>?
            var didCompletePlayback = false
            let playbackController = PlaybackSessionController()
            let controller = StockPlayerViewController(
                playbackController: playbackController,
                onPictureInPictureChanged: { _ in },
                onDismiss: { [weak self, weak playbackController] in
                    guard let self else { return }
                    seekTask?.cancel()
                    recoveryTask?.cancel()
                    self.presentedPlayerController = nil
                    let time = playbackController?.currentTimeMilliseconds ?? 0
                    let duration = playbackController?.durationMilliseconds

                    if !didCompletePlayback {
                        self.model.reportPlaybackTimeline(
                            for: playbackID,
                            state: .stopped,
                            time: time,
                            duration: duration,
                            sessionID: activeSessionID
                        )
                    }
                    playbackController?.stop()
                    self.model.stopPlaybackSession(for: playbackID, sessionID: activeRemoteSessionID)
                }
            )
            func load(_ resource: MediaPlaybackResource, canRecover: Bool) {
                let previousSessionID = activeRemoteSessionID
                activeRemoteSessionID = resource.remoteSessionID
                if previousSessionID != activeRemoteSessionID {
                    model.stopPlaybackSession(for: playbackID, sessionID: previousSessionID)
                }
                playbackController.load(
                    item: MediaPlayerItemFactory.item(resource: resource, mediaItem: item),
                    startOffsetMilliseconds: resource.localStartOffsetMilliseconds,
                    refreshesAfterLongPause: resource.remoteSessionID != nil,
                    onTimelineEvent: { [weak self] state, time, duration in
                        self?.model.reportPlaybackTimeline(
                            for: playbackID,
                            state: state,
                            time: time,
                            duration: duration,
                            sessionID: activeSessionID
                        )
                    },
                    onPlaybackEnded: { [weak self] time, duration in
                        didCompletePlayback = true
                        self?.model.reportPlaybackTimeline(
                            for: playbackID,
                            state: .stopped,
                            time: time,
                            duration: duration,
                            sessionID: activeSessionID
                        )
                        self?.model.markPlaybackCompleted(for: playbackID, sessionID: activeSessionID)
                        controller.dismiss(animated: true)
                    },
                    onRecoveryNeeded: { [weak self] savedTime, playbackError in
                        guard let self, canRecover else {
                            controller.dismiss(animated: true) {
                                if let playbackError {
                                    self?.presentPlaybackFailure(PlaybackFailure(
                                        playbackError,
                                        summary: "Playback failed after Freya restarted the stream."
                                    ))
                                }
                            }
                            return
                        }
                        recoveryTask?.cancel()
                        recoveryTask = Task {
                            let offset = max(savedTime, item.resumeOffsetMilliseconds ?? 0)
                            do {
                                let newSessionID = UUID().uuidString
                                let newResource = try await self.model.playbackURL(
                                    for: playbackID,
                                    sessionID: newSessionID,
                                    offsetMilliseconds: offset
                                )
                                guard !Task.isCancelled else {
                                    self.model.stopPlaybackSession(for: playbackID, sessionID: newResource.remoteSessionID)
                                    return
                                }
                                activeSessionID = newSessionID
                                load(newResource, canRecover: false)
                            } catch {
                                controller.dismiss(animated: true) {
                                    self.presentPlaybackFailure(PlaybackFailure(
                                        error,
                                        summary: "Freya couldn't restart playback."
                                    ))
                                }
                            }
                        }
                    },
                    onNavigationNeeded: resource.reloadsForSeek ? { [weak self] offset in
                        guard let self else { return }
                        seekTask?.cancel()
                        seekTask = Task {
                            do {
                                let newSessionID = UUID().uuidString
                                let newResource = try await self.model.playbackURL(
                                    for: playbackID,
                                    sessionID: newSessionID,
                                    offsetMilliseconds: offset
                                )
                                guard !Task.isCancelled else {
                                    self.model.stopPlaybackSession(for: playbackID, sessionID: newResource.remoteSessionID)
                                    return
                                }
                                activeSessionID = newSessionID
                                load(newResource, canRecover: canRecover)
                            } catch {
                                controller.dismiss(animated: true) {
                                    self.presentPlaybackFailure(PlaybackFailure(
                                        error,
                                        summary: "Freya couldn't seek to that position."
                                    ))
                                }
                            }
                        }
                    } : nil
                )
            }
            load(resource, canRecover: true)
            presentedPlayerController = controller
            presenter.present(controller, animated: true)
        } catch {
            presentPlaybackFailure(PlaybackFailure(error))
        }
    }

    private func presentPlaybackFailure(_ failure: PlaybackFailure) {
        guard let presenter, presenter.presentedViewController == nil else { return }

        let alert = UIAlertController(title: failure.title, message: failure.message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter.present(alert, animated: true)
    }
}

extension View {
    func mediaItemQuickActions(model: AppModel, item: MediaItem) -> some View {
        modifier(MediaItemQuickActionsModifier(model: model, item: item))
    }
}

private struct MediaItemQuickActionsModifier: ViewModifier {
    @ObservedObject var model: AppModel
    let item: MediaItem

    @State private var pendingPlayback: QuickPlayRequest?
    @State private var playbackFailure: PlaybackFailure?

    func body(content: Content) -> some View {
        content
            .contextMenu {
                if item.playbackID != nil || item.kind == .series {
                    Button {
                        Task { await startPlayback() }
                    } label: {
                        Label(quickPlayTitle, systemImage: "play.fill")
                    }
                    .disabled(model.isOffline)
                }

                Button {
                    model.setWatchStatus(for: item, isWatched: true)
                } label: {
                    Label(MediaWatchStatusDisplay.markSeenTitle, systemImage: "checkmark.circle.fill")
                }
                .disabled(model.isOffline)

                Button {
                    model.setWatchStatus(for: item, isWatched: false)
                } label: {
                    Label(MediaWatchStatusDisplay.markUnseenTitle, systemImage: "circle")
                }
                .disabled(model.isOffline)
            }
            .fullScreenCover(item: $pendingPlayback) { request in
                QuickPlaybackPresenter(
                    request: request,
                    model: model,
                    onPlayerDismissed: { pendingPlayback = nil },
                    onPlaybackFailed: { playbackFailure = PlaybackFailure($0) }
                )
                .ignoresSafeArea()
            }
            .alert(item: $playbackFailure) { failure in
                Alert(
                    title: Text(failure.title),
                    message: Text(failure.message),
                    dismissButton: .cancel(Text("OK"))
                )
            }
    }

    private var quickPlayTitle: String {
        model.cachedQuickPlayItem(for: item)?.quickPlayButtonTitle
            ?? item.quickPlayButtonTitle
    }

    private func startPlayback() async {
        guard let item = await model.quickPlayItem(for: item),
              let playbackID = item.playbackID else { return }

        do {
            let sessionID = UUID().uuidString
            let resource = try await model.playbackURL(
                for: playbackID,
                sessionID: sessionID,
                offsetMilliseconds: item.resumeOffsetMilliseconds
            )
            pendingPlayback = QuickPlayRequest(
                resource: resource,
                sessionID: sessionID,
                playbackID: playbackID,
                item: item
            )
        } catch {
            playbackFailure = PlaybackFailure(error)
        }
    }
}

private struct QuickPlayRequest: Identifiable {
    let id = UUID()
    let resource: MediaPlaybackResource
    let sessionID: String
    let playbackID: MediaPlaybackID
    let item: MediaItem
}

private struct QuickPlaybackPresenter: UIViewControllerRepresentable {
    let request: QuickPlayRequest
    let model: AppModel
    let onPlayerDismissed: () -> Void
    let onPlaybackFailed: (Error) -> Void

    func makeUIViewController(context: Context) -> StockPlayerViewController {
        var activeSessionID = request.sessionID
        var activeRemoteSessionID = request.resource.remoteSessionID
        var seekTask: Task<Void, Never>?
        var recoveryTask: Task<Void, Never>?
        var didCompletePlayback = false
        let playbackController = PlaybackSessionController()
        let controller = StockPlayerViewController(
            playbackController: playbackController,
            onPictureInPictureChanged: { _ in },
            onDismiss: {
                seekTask?.cancel()
                recoveryTask?.cancel()
                let time = playbackController.currentTimeMilliseconds
                let duration = playbackController.durationMilliseconds
                if !didCompletePlayback {
                    model.reportPlaybackTimeline(
                        for: request.playbackID,
                        state: .stopped,
                        time: time,
                        duration: duration,
                        sessionID: activeSessionID
                    )
                }
                playbackController.stop()
                model.stopPlaybackSession(for: request.playbackID, sessionID: activeRemoteSessionID)
                onPlayerDismissed()
            }
        )

        func load(_ resource: MediaPlaybackResource, canRecover: Bool) {
            let previousSessionID = activeRemoteSessionID
            activeRemoteSessionID = resource.remoteSessionID
            if previousSessionID != activeRemoteSessionID {
                model.stopPlaybackSession(for: request.playbackID, sessionID: previousSessionID)
            }
            playbackController.load(
                item: MediaPlayerItemFactory.item(resource: resource, mediaItem: request.item),
                startOffsetMilliseconds: resource.localStartOffsetMilliseconds,
                refreshesAfterLongPause: resource.remoteSessionID != nil,
                onTimelineEvent: { state, time, duration in
                    model.reportPlaybackTimeline(
                        for: request.playbackID,
                        state: state,
                        time: time,
                        duration: duration,
                        sessionID: activeSessionID
                    )
                },
                onPlaybackEnded: { time, duration in
                    didCompletePlayback = true
                    model.reportPlaybackTimeline(
                        for: request.playbackID,
                        state: .stopped,
                        time: time,
                        duration: duration,
                        sessionID: activeSessionID
                    )
                    model.markPlaybackCompleted(for: request.playbackID, sessionID: activeSessionID)
                    controller.dismiss(animated: true)
                },
                onRecoveryNeeded: { savedTime, playbackError in
                    guard canRecover else {
                        controller.dismiss(animated: true) {
                            if let playbackError { onPlaybackFailed(playbackError) }
                        }
                        return
                    }
                    recoveryTask?.cancel()
                    recoveryTask = Task {
                        let resumeOffset = max(savedTime, request.item.resumeOffsetMilliseconds ?? 0)
                        do {
                            let newSessionID = UUID().uuidString
                            let newResource = try await model.playbackURL(
                                for: request.playbackID,
                                sessionID: newSessionID,
                                offsetMilliseconds: resumeOffset
                            )
                            guard !Task.isCancelled else {
                                model.stopPlaybackSession(for: request.playbackID, sessionID: newResource.remoteSessionID)
                                return
                            }
                            activeSessionID = newSessionID
                            load(newResource, canRecover: false)
                        } catch {
                            controller.dismiss(animated: true) { onPlaybackFailed(error) }
                        }
                    }
                },
                onNavigationNeeded: resource.reloadsForSeek ? { offset in
                    seekTask?.cancel()
                    seekTask = Task {
                        do {
                            let newSessionID = UUID().uuidString
                            let newResource = try await model.playbackURL(
                                for: request.playbackID,
                                sessionID: newSessionID,
                                offsetMilliseconds: offset
                            )
                            guard !Task.isCancelled else {
                                model.stopPlaybackSession(for: request.playbackID, sessionID: newResource.remoteSessionID)
                                return
                            }
                            activeSessionID = newSessionID
                            load(newResource, canRecover: canRecover)
                        } catch {
                            controller.dismiss(animated: true) { onPlaybackFailed(error) }
                        }
                    }
                } : nil
            )
        }

        load(request.resource, canRecover: true)
        return controller
    }

    func updateUIViewController(_ controller: StockPlayerViewController, context: Context) {}
}
