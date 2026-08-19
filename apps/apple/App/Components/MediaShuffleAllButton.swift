import AVKit
import SwiftUI

struct MediaPlayAllButton: View {
    @ObservedObject var model: AppModel
    let items: [MediaItem]

    @State private var queue: [MediaItem] = []
    @State private var index = 0
    @State private var playbackController: PlaybackSessionController?
    @State private var sessionID = UUID().uuidString
    @State private var isLoading = false
    @State private var isShowingPlayer = false
    @State private var didFinishCurrent = false
    @State private var didRetryCurrent = false
    @State private var resumeOffset: Int?
    @State private var preparedNext: PreparedItem?
    @State private var activeRemoteSessionID: String?
    @State private var seekTask: Task<Void, Never>?
    @State private var recoveryTask: Task<Void, Never>?
    @State private var prepareTask: Task<Void, Never>?
    @State private var loadTask: Task<Void, Never>?
    @FocusState private var isPlayFocused: Bool

    var body: some View {
        Menu {
            Button("In Order") {
                begin(shuffled: false)
            }
            Button("Shuffle") {
                begin(shuffled: true)
            }
        } label: {
            if isLoading {
                ProgressView()
            } else {
                Label("Play All", systemImage: "play.fill")
            }
        }
        .buttonStyle(MediaGlassButtonStyle())
        .focused($isPlayFocused)
        .disabled(model.isOffline || isLoading || orderedPlayableItems.isEmpty)
        .fixedSize(horizontal: true, vertical: false)
        .task {
            isPlayFocused = true
        }
        .fullScreenCover(isPresented: $isShowingPlayer, onDismiss: stop) {
            if let playbackController {
                StockPlayerView(
                    playbackController: playbackController,
                    onPictureInPictureChanged: { _ in }
                )
                .ignoresSafeArea()
            }
        }
    }

    private var orderedPlayableItems: [MediaItem] {
        items.filter { $0.playbackID != nil }
    }

    private var currentItem: MediaItem? {
        queue.indices.contains(index) ? queue[index] : nil
    }

    private func begin(shuffled: Bool) {
        loadTask?.cancel()
        loadTask = Task { await start(shuffled: shuffled) }
    }

    private func start(shuffled: Bool) async {
        let items = orderedPlayableItems
        queue = shuffled ? items.shuffled() : items
        index = 0
        didRetryCurrent = false
        preparedNext = nil
        resumeOffset = nil
        await loadCurrent(showPlayer: true)
    }

    private func loadCurrent(showPlayer: Bool = false) async {
        guard !Task.isCancelled else { return }
        guard let item = currentItem, let id = item.playbackID else {
            isShowingPlayer = false
            return
        }
        let currentIndex = index

        isLoading = true
        defer { isLoading = false }

        do {
            let startOffset = resumeOffset ?? item.resumeOffsetMilliseconds
            let nextSessionID = UUID().uuidString
            let resource = try await model.playbackURL(
                for: id,
                sessionID: nextSessionID,
                offsetMilliseconds: startOffset
            )
            guard !Task.isCancelled, index == currentIndex else {
                model.stopPlaybackSession(for: id, sessionID: resource.remoteSessionID)
                return
            }
            sessionID = nextSessionID
            didFinishCurrent = false
            resumeOffset = nil
            loadPlayerItem(resource, mediaItem: item)
            schedulePrepareNext()
            if showPlayer {
                isShowingPlayer = true
            }
        } catch {
            guard !Task.isCancelled, index == currentIndex else { return }
            index += 1
            didRetryCurrent = false
            await loadCurrent(showPlayer: showPlayer)
        }
    }

    private func stop() {
        seekTask?.cancel()
        recoveryTask?.cancel()
        prepareTask?.cancel()
        loadTask?.cancel()
        seekTask = nil
        recoveryTask = nil
        prepareTask = nil
        loadTask = nil
        let playbackID = currentItem?.playbackID ?? queue.compactMap(\.playbackID).first
        if let playbackID { reportStop(for: playbackID) }
        playbackController?.stop()
        playbackController = nil
        if let playbackID {
            model.stopPlaybackSession(for: playbackID, sessionID: activeRemoteSessionID)
        }
        activeRemoteSessionID = nil
        if let preparedNext,
           queue.indices.contains(preparedNext.index),
           let preparedID = queue[preparedNext.index].playbackID {
            model.stopPlaybackSession(for: preparedID, sessionID: preparedNext.resource.remoteSessionID)
        }
        preparedNext = nil
    }

    private func reportStop(for id: MediaPlaybackID) {
        guard !didFinishCurrent else { return }
        model.reportPlaybackTimeline(
            for: id,
            state: .stopped,
            time: playbackController?.currentTimeMilliseconds ?? 0,
            duration: playbackController?.durationMilliseconds,
            sessionID: sessionID
        )
    }

    private func reportTimeline(state: MediaPlaybackTimelineState, time: Int, duration: Int?) {
        guard let id = currentItem?.playbackID else { return }
        model.reportPlaybackTimeline(for: id, state: state, time: time, duration: duration, sessionID: sessionID)
    }

    private func playbackEnded(time: Int, duration: Int?) {
        guard let id = currentItem?.playbackID else { return }

        didFinishCurrent = true
        model.reportPlaybackTimeline(for: id, state: .stopped, time: time, duration: duration, sessionID: sessionID)
        model.markPlaybackCompleted(for: id, sessionID: sessionID)
        advance(to: index + 1)
    }

    private func advance(to nextIndex: Int) {
        index = nextIndex
        didRetryCurrent = false
        if let preparedNext, preparedNext.index == index, currentItem != nil {
            sessionID = preparedNext.sessionID
            didFinishCurrent = false
            resumeOffset = nil
            loadPlayerItem(preparedNext.resource, mediaItem: queue[index])
            self.preparedNext = nil
            schedulePrepareNext()
        } else {
            loadTask?.cancel()
            loadTask = Task { await loadCurrent() }
        }
    }

    private func recoverCurrent(resumeOffset savedTime: Int) async {
        guard let playbackController, !isLoading else { return }
        guard !didRetryCurrent else {
            advance(to: index + 1)
            return
        }
        didRetryCurrent = true
        resumeOffset = savedTime > 0
            ? savedTime
            : max(playbackController.currentTimeMilliseconds, currentItem?.resumeOffsetMilliseconds ?? 0)
        await loadCurrent()
    }

    private func restartCurrent(at offset: Int) async {
        resumeOffset = offset
        await loadCurrent()
    }

    private func prepareNext(after currentIndex: Int) async {
        let nextIndex = currentIndex + 1
        guard queue.indices.contains(nextIndex), let id = queue[nextIndex].playbackID else { return }

        do {
            let nextSessionID = UUID().uuidString
            let resource = try await model.playbackURL(for: id, sessionID: nextSessionID)
            guard !Task.isCancelled else {
                model.stopPlaybackSession(for: id, sessionID: resource.remoteSessionID)
                return
            }
            preparedNext = PreparedItem(
                index: nextIndex,
                resource: resource,
                sessionID: nextSessionID
            )
        } catch {
            preparedNext = nil
        }
    }

    private func schedulePrepareNext() {
        prepareTask?.cancel()
        let currentIndex = index
        prepareTask = Task {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            await prepareNext(after: currentIndex)
        }
    }

    private func loadPlayerItem(_ resource: MediaPlaybackResource, mediaItem: MediaItem) {
        let previousSessionID = activeRemoteSessionID
        activeRemoteSessionID = resource.remoteSessionID
        if previousSessionID != activeRemoteSessionID, let id = currentItem?.playbackID {
            model.stopPlaybackSession(for: id, sessionID: previousSessionID)
        }

        let controller = playbackController ?? PlaybackSessionController()
        playbackController = controller
        controller.load(
            item: MediaPlayerItemFactory.item(resource: resource, mediaItem: mediaItem),
            startOffsetMilliseconds: resource.localStartOffsetMilliseconds,
            refreshesAfterLongPause: resource.remoteSessionID != nil,
            onTimelineEvent: reportTimeline(state:time:duration:),
            onPlaybackEnded: playbackEnded(time:duration:),
            onRecoveryNeeded: { savedTime, _ in
                recoveryTask?.cancel()
                recoveryTask = Task { await recoverCurrent(resumeOffset: savedTime) }
            },
            onNavigationNeeded: resource.reloadsForSeek
                ? { offset in
                    seekTask?.cancel()
                    seekTask = Task { await restartCurrent(at: offset) }
                }
                : nil
        )
    }

    private struct PreparedItem {
        let index: Int
        let resource: MediaPlaybackResource
        let sessionID: String
    }
}
