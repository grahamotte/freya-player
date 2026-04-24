import AVKit
import SwiftUI

struct MediaPlayButton: View {
    @ObservedObject var model: AppModel
    let id: MediaPlaybackID
    let hasResume: Bool
    let resumeOffsetMilliseconds: Int?
    var onPlaybackDismissed: () async -> Void = {}

    @FocusState private var focusedControl: FocusedControl?

    @State private var isLoading = false
    @State private var isLoadingOptions = false
    @State private var playbackOptions: MediaPlaybackOptions?
    @State private var playbackError: String?
    @State private var selectedAudioID: String?
    @State private var selectedSubtitleID: String?
    @State private var player: AVPlayer?
    @State private var isShowingPlayer = false
    @State private var playbackSessionID = UUID().uuidString
    @State private var didCompletePlayback = false
    @State private var playbackUpdateTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Button {
                    Task {
                        await startPlayback()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(hasResume ? "Resume" : "Play")
                    }
                }
                .buttonStyle(MediaGlassButtonStyle())
                .disabled(isLoading)

                if let playbackOptions, playbackOptions.audioOptions.count > 1 {
                    Menu {
                        ForEach(playbackOptions.audioOptions) { option in
                            Button(option.title) {
                                selectedAudioID = option.id
                            }
                        }
                    } label: {
                        accessoryLabel(
                            systemName: "globe",
                            title: selectedAudioTitle ?? "Audio",
                            isFocused: focusedControl == .audio
                        )
                    }
                    .buttonStyle(MediaGlassButtonStyle())
                    .focused($focusedControl, equals: .audio)
                    .disabled(isLoading || isLoadingOptions)
                }

                if let playbackOptions, !playbackOptions.subtitleOptions.isEmpty {
                    Menu {
                        Button("None") {
                            selectedSubtitleID = nil
                        }

                        ForEach(playbackOptions.subtitleOptions) { option in
                            Button(option.title) {
                                selectedSubtitleID = option.id
                            }
                        }
                    } label: {
                        accessoryLabel(
                            systemName: "captions.bubble",
                            title: selectedSubtitleTitle ?? "None",
                            isFocused: focusedControl == .subtitle
                        )
                    }
                    .buttonStyle(MediaGlassButtonStyle())
                    .focused($focusedControl, equals: .subtitle)
                    .disabled(isLoading || isLoadingOptions)
                }
            }

            if let playbackError {
                Text(playbackError)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .task(id: id) {
            await refreshPlaybackOptions()
        }
        .fullScreenCover(isPresented: $isShowingPlayer, onDismiss: stopPlayback) {
            if let player {
                StockPlayerView(
                    player: player,
                    resumeOffsetMilliseconds: resumeOffsetMilliseconds,
                    onTimelineEvent: reportTimeline(state:time:duration:),
                    onPlaybackEnded: playbackEnded(time:duration:)
                )
                    .ignoresSafeArea()
            }
        }
    }

    private var selectedAudioTitle: String? {
        playbackOptions?.audioOptions.first(where: { $0.id == selectedAudioID })?.title
    }

    private var selectedSubtitleTitle: String? {
        guard let selectedSubtitleID else { return "None" }
        return playbackOptions?.subtitleOptions.first(where: { $0.id == selectedSubtitleID })?.title
    }

    private func startPlayback() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if playbackOptions == nil {
                try await fetchPlaybackOptions()
            }

            let sessionID = UUID().uuidString
            let url = try await model.playbackURL(
                for: id,
                selection: playbackSelection,
                sessionID: sessionID
            )
            playbackError = nil
            playbackSessionID = sessionID
            didCompletePlayback = false
            playbackUpdateTask = nil
            player = AVPlayer(url: url)
            isShowingPlayer = true
        } catch {
            playbackError = "Playback isn't ready right now."
        }
    }

    private func refreshPlaybackOptions() async {
        do {
            try await fetchPlaybackOptions()
        } catch {
            playbackError = "Playback isn't ready right now."
        }
    }

    private func fetchPlaybackOptions() async throws {
        guard !isLoadingOptions else { return }
        isLoadingOptions = true
        defer { isLoadingOptions = false }

        let options = try await model.playbackOptions(for: id)
        playbackOptions = options
        applyDefaultSelection(using: options)
        playbackError = nil
    }

    private func applyDefaultSelection(using options: MediaPlaybackOptions?) {
        guard let options else {
            selectedAudioID = nil
            selectedSubtitleID = nil
            return
        }

        selectedAudioID = options.selectedAudioID ?? options.audioOptions.first?.id
        selectedSubtitleID = options.selectedSubtitleID
    }

    private var playbackSelection: MediaPlaybackSelection? {
        guard let playbackOptions else {
            return nil
        }

        let audioChanged = selectedAudioID != playbackOptions.selectedAudioID
        let subtitleChanged = selectedSubtitleID != playbackOptions.selectedSubtitleID

        guard audioChanged || subtitleChanged else {
            return nil
        }

        return MediaPlaybackSelection(
            audioID: selectedAudioID,
            subtitleID: selectedSubtitleID
        )
    }

    @ViewBuilder
    private func accessoryLabel(systemName: String, title: String, isFocused: Bool) -> some View {
        let label = Label(title, systemImage: systemName)

        if isFocused {
            label
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
        } else {
            label
                .labelStyle(.iconOnly)
        }
    }

    private func stopPlayback() {
        let time = player?.currentTime().milliseconds ?? 0
        let duration = player?.currentItem?.duration.milliseconds
        let pendingPlaybackUpdateTask = playbackUpdateTask
        player?.pause()
        player = nil

        Task {
            if didCompletePlayback {
                await pendingPlaybackUpdateTask?.value
            } else {
                await reportTimelineNow(
                    state: .stopped,
                    time: time,
                    duration: duration
                )
            }

            await onPlaybackDismissed()
        }
    }

    private func reportTimeline(state: MediaPlaybackTimelineState, time: Int, duration: Int?) {
        Task {
            await reportTimelineNow(state: state, time: time, duration: duration)
        }
    }

    private func reportTimelineNow(state: MediaPlaybackTimelineState, time: Int, duration: Int?) async {
        await model.reportPlaybackTimeline(
            for: id,
            state: state,
            time: time,
            duration: duration,
            sessionID: playbackSessionID
        )
    }

    private func playbackEnded(time: Int, duration: Int?) {
        didCompletePlayback = true
        playbackUpdateTask = Task {
            await reportTimelineNow(state: .stopped, time: time, duration: duration)
            await model.markPlaybackCompleted(for: id)
        }
        isShowingPlayer = false
    }

    private enum FocusedControl {
        case audio
        case subtitle
    }
}

private struct StockPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    let resumeOffsetMilliseconds: Int?
    let onTimelineEvent: (MediaPlaybackTimelineState, Int, Int?) -> Void
    let onPlaybackEnded: (Int, Int?) -> Void

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        context.coordinator.bind(
            to: player,
            resumeOffsetMilliseconds: resumeOffsetMilliseconds,
            onTimelineEvent: onTimelineEvent,
            onPlaybackEnded: onPlaybackEnded
        )
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
        context.coordinator.bind(
            to: player,
            resumeOffsetMilliseconds: resumeOffsetMilliseconds,
            onTimelineEvent: onTimelineEvent,
            onPlaybackEnded: onPlaybackEnded
        )
        player.play()
    }

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.unbind()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private let lifecycle = MediaPlayerLifecycle()

        func bind(
            to player: AVPlayer,
            resumeOffsetMilliseconds: Int?,
            onTimelineEvent: @escaping (MediaPlaybackTimelineState, Int, Int?) -> Void,
            onPlaybackEnded: @escaping (Int, Int?) -> Void
        ) {
            lifecycle.bind(
                to: player,
                resumeOffsetMilliseconds: resumeOffsetMilliseconds,
                onTimelineEvent: onTimelineEvent,
                onPlaybackEnded: onPlaybackEnded
            )
        }

        func unbind() {
            lifecycle.unbind()
        }
    }
}
