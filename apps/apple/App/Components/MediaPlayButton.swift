import AVKit
import SwiftUI
import UIKit

struct MediaPlayButton: View {
    @ObservedObject var model: AppModel
    let item: MediaItem
    let id: MediaPlaybackID
    var onPlaybackDismissed: () -> Void = {}

    @FocusState private var isPlayFocused: Bool

    @State private var isLoading = false
    @State private var isLoadingOptions = false
    @State private var playbackOptions: MediaPlaybackOptions?
    @State private var playbackFailure: PlaybackFailure?
    @State private var playbackDialogError: String?
    @State private var isShowingPlaybackDialog = false
    @State private var isHandlingLongPress = false
    @State private var playsAfterDialogDismisses = false
    @State private var draftQuality: MediaPlaybackQuality = .automatic
    @State private var draftAudioID: String?
    @State private var draftSubtitleID: String?
    @State private var activeSelection: MediaPlaybackSelection?
    @State private var playbackSessionID = UUID().uuidString
    @State private var didCompletePlayback = false
    @State private var didRetryPlayback = false
    @State private var currentResumeOffset: Int?
    @State private var playbackController: PlaybackSessionController?
    @State private var presentedPlayerController: StockPlayerViewController?
    @State private var activeRemoteSessionID: String?
    @State private var seekTask: Task<Void, Never>?
    @State private var recoveryTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                guard !isHandlingLongPress else {
                    isHandlingLongPress = false
                    return
                }

                Task {
                    await startPlayback(selection: nil)
                }
            } label: {
                Label {
                    Text(item.hasResume ? "Resume" : "Play")
                } icon: {
                    Image(systemName: "play.fill")
                        .opacity(isLoading ? 0 : 1)
                        .overlay {
                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                }
            }
            .buttonStyle(MediaGlassButtonStyle())
            .focused($isPlayFocused)
            .disabled(isLoading)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        isHandlingLongPress = true
                        Task {
                            await showPlaybackDialog()
                            try? await Task.sleep(for: .milliseconds(700))
                            isHandlingLongPress = false
                        }
                    }
            )

        }
        .task(id: id) {
            isPlayFocused = true
        }
        .onChange(of: draftQuality) { playbackDialogError = nil }
        .onChange(of: draftAudioID) { playbackDialogError = nil }
        .onChange(of: draftSubtitleID) { playbackDialogError = nil }
        .modifier(PlaybackDialogModifier(
            isPresented: $isShowingPlaybackDialog,
            isLoading: isLoading,
            error: playbackDialogError,
            qualityOptions: qualityOptions,
            audioOptions: playbackOptions?.audioOptions ?? [],
            subtitleOptions: playbackOptions?.subtitleOptions ?? [],
            draftQuality: $draftQuality,
            draftAudioID: $draftAudioID,
            draftSubtitleID: $draftSubtitleID,
            playTitle: item.hasResume ? "Resume" : "Play",
            onClose: {
                isShowingPlaybackDialog = false
            },
            onPlay: {
                playsAfterDialogDismisses = true
                isShowingPlaybackDialog = false
            },
            onDismiss: {
                guard playsAfterDialogDismisses else { return }
                playsAfterDialogDismisses = false
                Task {
                    await startPlayback(selection: draftPlaybackSelection)
                }
            }
        ))
        .alert(item: $playbackFailure) { failure in
            Alert(
                title: Text(failure.title),
                message: Text(failure.message),
                dismissButton: .cancel(Text("OK"))
            )
        }
    }

    private var qualityOptions: [MediaPlaybackQuality] {
        let options = playbackOptions?.qualityOptions ?? MediaPlaybackQuality.allCases
        return [.automatic] + options.filter { $0 != .automatic }
    }

    @discardableResult
    private func startPlayback(selection: MediaPlaybackSelection?) async -> Bool {
        isLoading = true

        let sessionID = UUID().uuidString
        playbackFailure = nil
        activeSelection = selection
        playbackSessionID = sessionID
        didCompletePlayback = false
        didRetryPlayback = false
        currentResumeOffset = nil
        let controller = playbackController ?? PlaybackSessionController()
        playbackController = controller

        do {
            let resource = try await model.playbackURL(
                for: id,
                selection: selection,
                sessionID: sessionID,
                offsetMilliseconds: item.resumeOffsetMilliseconds
            )
            guard playbackController === controller else {
                model.stopPlaybackSession(for: id, sessionID: resource.remoteSessionID)
                isLoading = false
                return false
            }
            load(controller, resource: resource, autoplay: false)
            presentPlayerViewController(controller) {
                isLoading = false
            }
            return true
        } catch {
            guard playbackController === controller else {
                isLoading = false
                return false
            }
            playbackFailure = PlaybackFailure(error)
            controller.stop()
            playbackController = nil
            isLoading = false
            return false
        }
    }

    private func load(
        _ controller: PlaybackSessionController,
        resource: MediaPlaybackResource,
        autoplay: Bool = true
    ) {
        let previousSessionID = activeRemoteSessionID
        activeRemoteSessionID = resource.remoteSessionID
        if previousSessionID != activeRemoteSessionID {
            model.stopPlaybackSession(for: id, sessionID: previousSessionID)
        }

        let navigationHandler: ((Int) -> Void)? = resource.reloadsForSeek
            ? { restartPlayback(at: $0) }
            : nil
        controller.load(
            item: MediaPlayerItemFactory.item(resource: resource, mediaItem: item),
            startOffsetMilliseconds: resource.localStartOffsetMilliseconds,
            enableSubtitles: activeSelection?.subtitleID != nil,
            refreshesAfterLongPause: resource.remoteSessionID != nil,
            autoplay: autoplay,
            onTimelineEvent: reportTimeline(state:time:duration:),
            onPlaybackEnded: playbackEnded(time:duration:),
            onRecoveryNeeded: handleRecovery(resumeOffset:error:),
            onNavigationNeeded: navigationHandler
        )
    }

    private func presentPlayerViewController(
        _ playbackController: PlaybackSessionController,
        completion: (() -> Void)? = nil
    ) {
        if let controller = presentedPlayerController, controller.view.window != nil {
            controller.configure(
                to: playbackController,
                onPictureInPictureChanged: pictureInPictureChanged
            )
            completion?()
            return
        }

        presentedPlayerController?.clearDismissHandler()
        guard let presenter = rootPresenter() else {
            completion?()
            return
        }

        let controller = StockPlayerViewController(
            playbackController: playbackController,
            onPictureInPictureChanged: pictureInPictureChanged,
            onDismiss: stopPlayback
        )
        presentedPlayerController = controller
        presenter.present(controller, animated: true, completion: completion)
    }

    private func rootPresenter() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        var presenter = window?.rootViewController
        while let presented = presenter?.presentedViewController {
            presenter = presented
        }
        return presenter
    }

    private func showPlaybackDialog() async {
        do {
            if playbackOptions == nil {
                try await fetchPlaybackOptions()
            }
            playbackFailure = nil
            playbackDialogError = nil
            resetDraftSelection()
            isShowingPlaybackDialog = true
        } catch {
            playbackFailure = PlaybackFailure(error, summary: "Freya couldn't load playback options.")
        }
    }

    private func fetchPlaybackOptions() async throws {
        guard !isLoadingOptions else { return }
        isLoadingOptions = true
        defer { isLoadingOptions = false }

        let options = try await model.playbackOptions(for: id)
        playbackOptions = options
        playbackFailure = nil
    }

    private func resetDraftSelection() {
        draftQuality = .automatic
        draftAudioID = nil
        draftSubtitleID = nil
    }

    private var draftPlaybackSelection: MediaPlaybackSelection? {
        let qualityChanged = draftQuality != .automatic
        let audioChanged = draftAudioID != nil
        let subtitleChanged = draftSubtitleID != nil

        guard qualityChanged || audioChanged || subtitleChanged else {
            return nil
        }

        return MediaPlaybackSelection(
            quality: draftQuality,
            audioID: draftAudioID,
            subtitleID: draftSubtitleID
        )
    }

    private func stopPlayback() {
        seekTask?.cancel()
        recoveryTask?.cancel()
        seekTask = nil
        recoveryTask = nil
        let controller = playbackController
        presentedPlayerController = nil

        let time = controller?.currentTimeMilliseconds ?? 0
        let duration = controller?.durationMilliseconds

        if !didCompletePlayback {
            reportTimeline(state: .stopped, time: time, duration: duration)
        }

        controller?.stop()
        playbackController = nil
        model.stopPlaybackSession(for: id, sessionID: activeRemoteSessionID)
        activeRemoteSessionID = nil
        onPlaybackDismissed()
    }

    private func handleRecovery(resumeOffset savedTime: Int, error: Error?) {
        guard !didRetryPlayback else {
            playbackFailure = error.map {
                PlaybackFailure($0, summary: "Playback failed after Freya restarted the stream.")
            } ?? PlaybackFailure(
                summary: "Playback stopped responding.",
                details: "The player failed again after Freya restarted the stream."
            )
            presentedPlayerController?.dismiss(animated: true)
            return
        }
        didRetryPlayback = true

        recoveryTask?.cancel()
        recoveryTask = Task {
            isLoading = true
            defer { isLoading = false }
            let resumeOffset = savedTime > 0
                ? savedTime
                : currentResumeOffset ?? item.resumeOffsetMilliseconds ?? 0

            do {
                let newSessionID = UUID().uuidString
                let resource = try await model.playbackURL(
                    for: id,
                    selection: activeSelection,
                    sessionID: newSessionID,
                    offsetMilliseconds: resumeOffset
                )
                guard !Task.isCancelled else {
                    model.stopPlaybackSession(for: id, sessionID: resource.remoteSessionID)
                    return
                }
                playbackSessionID = newSessionID
                currentResumeOffset = resumeOffset
                let controller = playbackController ?? PlaybackSessionController()
                playbackController = controller
                load(controller, resource: resource)
                presentPlayerViewController(controller)
            } catch {
                guard !Task.isCancelled else { return }
                playbackFailure = PlaybackFailure(error, summary: "Freya couldn't restart playback.")
                presentedPlayerController?.dismiss(animated: true)
            }
        }
    }

    private func restartPlayback(at offset: Int) {
        currentResumeOffset = offset
        seekTask?.cancel()
        seekTask = Task {
            do {
                let newSessionID = UUID().uuidString
                let resource = try await model.playbackURL(
                    for: id,
                    selection: activeSelection,
                    sessionID: newSessionID,
                    offsetMilliseconds: offset
                )
                guard !Task.isCancelled,
                      currentResumeOffset == offset,
                      let controller = playbackController else {
                    model.stopPlaybackSession(for: id, sessionID: resource.remoteSessionID)
                    return
                }
                playbackSessionID = newSessionID
                load(controller, resource: resource)
            } catch {
                guard !Task.isCancelled else { return }
                playbackFailure = PlaybackFailure(error, summary: "Freya couldn't seek to that position.")
                presentedPlayerController?.dismiss(animated: true)
            }
        }
    }

    private func reportTimeline(state: MediaPlaybackTimelineState, time: Int, duration: Int?) {
        model.reportPlaybackTimeline(
            for: id,
            state: state,
            time: time,
            duration: duration,
            sessionID: playbackSessionID
        )
    }

    private func playbackEnded(time: Int, duration: Int?) {
        didCompletePlayback = true
        reportTimeline(state: .stopped, time: time, duration: duration)
        model.markPlaybackCompleted(for: id, sessionID: playbackSessionID)
        presentedPlayerController?.dismiss(animated: true)
        presentedPlayerController = nil
        playbackController?.stop()
        playbackController = nil
        model.stopPlaybackSession(for: id, sessionID: activeRemoteSessionID)
        activeRemoteSessionID = nil
    }

    private func pictureInPictureChanged(_ isActive: Bool) {
        if !isActive && presentedPlayerController == nil {
            stopPlayback()
        }
    }

}

private struct PlaybackDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let isLoading: Bool
    let error: String?
    let qualityOptions: [MediaPlaybackQuality]
    let audioOptions: [MediaPlaybackOption]
    let subtitleOptions: [MediaPlaybackOption]
    @Binding var draftQuality: MediaPlaybackQuality
    @Binding var draftAudioID: String?
    @Binding var draftSubtitleID: String?
    let playTitle: String
    let onClose: () -> Void
    let onPlay: () -> Void
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        #if targetEnvironment(macCatalyst)
        content
            .fullScreenCover(isPresented: $isPresented, onDismiss: onDismiss) {
                PlaybackOptionsDialog(
                    isLoading: isLoading,
                    error: error,
                    qualityOptions: qualityOptions,
                    audioOptions: audioOptions,
                    subtitleOptions: subtitleOptions,
                    draftQuality: $draftQuality,
                    draftAudioID: $draftAudioID,
                    draftSubtitleID: $draftSubtitleID,
                    playTitle: playTitle,
                    onClose: onClose,
                    onPlay: onPlay
                )
            }
        #else
        content
            .sheet(isPresented: $isPresented, onDismiss: onDismiss) {
                PlaybackOptionsDialog(
                    isLoading: isLoading,
                    error: error,
                    qualityOptions: qualityOptions,
                    audioOptions: audioOptions,
                    subtitleOptions: subtitleOptions,
                    draftQuality: $draftQuality,
                    draftAudioID: $draftAudioID,
                    draftSubtitleID: $draftSubtitleID,
                    playTitle: playTitle,
                    onClose: onClose,
                    onPlay: onPlay
                )
            }
        #endif
    }
}

private struct PlaybackOptionsDialog: View {
    let isLoading: Bool
    let error: String?
    let qualityOptions: [MediaPlaybackQuality]
    let audioOptions: [MediaPlaybackOption]
    let subtitleOptions: [MediaPlaybackOption]
    @Binding var draftQuality: MediaPlaybackQuality
    @Binding var draftAudioID: String?
    @Binding var draftSubtitleID: String?
    let playTitle: String
    let onClose: () -> Void
    let onPlay: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Play Options")
                    .font(dialogTitleFont)

                Spacer()

#if !os(tvOS)
                Button {
                    dismiss()
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .frame(width: 44, height: 44)
#endif
            }

            VStack(spacing: 12) {
                playbackMenu(title: title(for: draftQuality), systemImage: "display") {
                    ForEach(qualityOptions) { quality in
                        Button {
                            draftQuality = quality
                        } label: {
                            PlaybackOptionsMenuItem(title: title(for: quality), isSelected: quality == draftQuality)
                        }
                    }
                }

                playbackMenu(title: audioTitle, systemImage: "speaker.wave.3.fill") {
                    Button {
                        draftAudioID = nil
                    } label: {
                        PlaybackOptionsMenuItem(title: "Default Language", isSelected: draftAudioID == nil)
                    }

                    ForEach(audioOptions) { option in
                        Button {
                            draftAudioID = option.id
                        } label: {
                            PlaybackOptionsMenuItem(title: option.title, isSelected: option.id == draftAudioID)
                        }
                    }
                }

                playbackMenu(title: subtitleTitle, systemImage: "captions.bubble") {
                    Button {
                        draftSubtitleID = nil
                    } label: {
                        PlaybackOptionsMenuItem(title: "Default Subtitles", isSelected: draftSubtitleID == nil)
                    }

                    ForEach(subtitleOptions) { option in
                        Button {
                            draftSubtitleID = option.id
                        } label: {
                            PlaybackOptionsMenuItem(title: option.title, isSelected: option.id == draftSubtitleID)
                        }
                    }
                }
            }

            Button(action: onPlay) {
                Label(playTitle, systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MediaGlassButtonStyle(horizontalPadding: 22, verticalPadding: 12))
            .disabled(isLoading)

            if let error {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .foregroundStyle(AppTheme.primaryText)
        .padding(28)
        .frame(maxWidth: 520)
        .presentationSizing(.fitted)
    }

    private var dialogTitleFont: Font {
#if os(tvOS)
        .system(size: 28, weight: .bold)
#else
        .title2.bold()
#endif
    }

    private var audioTitle: String {
        guard let draftAudioID else { return "Default Language" }
        return audioOptions.first(where: { $0.id == draftAudioID })?.title ?? "Default Language"
    }

    private var subtitleTitle: String {
        guard let draftSubtitleID else { return "Default Subtitles" }
        return subtitleOptions.first(where: { $0.id == draftSubtitleID })?.title ?? "Default Subtitles"
    }

    private func title(for quality: MediaPlaybackQuality) -> String {
        quality == .automatic ? "Default Resolution" : quality.title
    }

    private func playbackMenu<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu(content: content) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(MediaGlassButtonStyle(horizontalPadding: 22, verticalPadding: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PlaybackOptionsMenuItem: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}

struct StockPlayerView: UIViewControllerRepresentable {
    let playbackController: PlaybackSessionController
    let onPictureInPictureChanged: (Bool) -> Void

    func makeUIViewController(context: Context) -> StockPlayerViewController {
        StockPlayerViewController(
            playbackController: playbackController,
            onPictureInPictureChanged: onPictureInPictureChanged,
        )
    }

    func updateUIViewController(_ controller: StockPlayerViewController, context: Context) {
        controller.configure(
            to: playbackController,
            onPictureInPictureChanged: onPictureInPictureChanged
        )
    }

    static func dismantleUIViewController(_ controller: StockPlayerViewController, coordinator: ()) {}
}

final class StockPlayerViewController: AVPlayerViewController, AVPlayerViewControllerDelegate {
    var playbackController: PlaybackSessionController
    private var onPictureInPictureChanged: (Bool) -> Void
    private var onDismiss: (() -> Void)?

    private var didDismiss = false
    private var isPictureInPictureActive = false
    private weak var pictureInPicturePresenter: UIViewController?

    init(
        playbackController: PlaybackSessionController,
        onPictureInPictureChanged: @escaping (Bool) -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        self.playbackController = playbackController
        self.onPictureInPictureChanged = onPictureInPictureChanged
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        delegate = self
        player = playbackController.player
#if os(iOS)
        allowsPictureInPicturePlayback = true
#endif
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        pictureInPicturePresenter = presentingViewController ?? pictureInPicturePresenter
        playbackController.play()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard !isPictureInPictureActive else { return }
        playbackController.pause()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard !isPictureInPictureActive else { return }
        finishDismissalIfNeeded()
    }

    func configure(
        to playbackController: PlaybackSessionController,
        onPictureInPictureChanged: @escaping (Bool) -> Void
    ) {
        self.onPictureInPictureChanged = onPictureInPictureChanged

        guard self.playbackController !== playbackController else {
            playbackController.play()
            return
        }

        self.playbackController = playbackController
        player = playbackController.player
        playbackController.play()
    }

    func clearDismissHandler() {
        onDismiss = nil
    }

#if os(tvOS)
    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        timeToSeekAfterUserNavigatedFrom oldTime: CMTime,
        to targetTime: CMTime
    ) -> CMTime {
        playbackController.userNavigated(to: targetTime)
        return targetTime
    }
#endif

    private func finishDismissalIfNeeded() {
        guard !didDismiss else { return }
        didDismiss = true
        onDismiss?()
    }

    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        isPictureInPictureActive = true
        onPictureInPictureChanged(true)
    }

    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        isPictureInPictureActive = false
        onPictureInPictureChanged(false)
        if view.window == nil {
            finishDismissalIfNeeded()
        }
    }

    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        guard view.window == nil else {
            completionHandler(true)
            return
        }

        guard let pictureInPicturePresenter, pictureInPicturePresenter.view.window != nil else {
            completionHandler(false)
            return
        }

        pictureInPicturePresenter.present(playerViewController, animated: true) {
            completionHandler(true)
        }
    }
}
