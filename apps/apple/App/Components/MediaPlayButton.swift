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

                let settings = model.playbackSettings(for: id)
                Task {
                    await startPlayback(settings: settings)
                }
            } label: {
                Label {
                    Text(item.hasResume ? "Resume" : "Play")
                } icon: {
                    Image(systemName: "play.fill")
                        .opacity(isLoadingOptions ? 0 : 1)
                        .overlay {
                            if isLoadingOptions {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                }
            }
            .buttonStyle(MediaGlassButtonStyle())
            .focused($isPlayFocused)
            .disabled(model.isOffline || isLoading || isLoadingOptions)
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
            isOffline: model.isOffline,
            error: playbackDialogError,
            qualityOptions: qualityOptions,
            defaultResolutionTitle: defaultResolutionTitle,
            audioOptions: playbackOptions?.audioOptions ?? [],
            subtitleOptions: playbackOptions?.subtitleOptions ?? [],
            selectedAudioID: playbackOptions?.selectedAudioID,
            selectedSubtitleID: playbackOptions?.selectedSubtitleID,
            defaultVideoTranscoding: playbackOptions?.defaultVideoTranscoding,
            defaultAudioTranscoding: playbackOptions?.defaultAudioTranscoding,
            draftQuality: $draftQuality,
            draftAudioID: $draftAudioID,
            draftSubtitleID: $draftSubtitleID,
            playTitle: item.playButtonTitle,
            onClose: {
                isShowingPlaybackDialog = false
            },
            onPlay: {
                let selection = draftPlaybackSelection
                model.setPlaybackSettings(MediaPlaybackSettings(selection: selection), for: id)
                isLoading = true
                isShowingPlaybackDialog = false
                Task {
                    await startPlayback(selection: selection)
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
        [.automatic] + (playbackOptions?.qualityOptions
            ?? MediaPlaybackQuality.transcodingOptions(forVideoHeight: nil))
    }

    private var defaultResolutionTitle: String {
        playbackOptions?.defaultResolutionTitle ?? "Automatic (Default)"
    }

    @discardableResult
    private func startPlayback(selection: MediaPlaybackSelection?) async -> Bool {
        await startPlayback(selection: selection, settings: nil)
    }

    @discardableResult
    private func startPlayback(settings: MediaPlaybackSettings?) async -> Bool {
        await startPlayback(selection: nil, settings: settings)
    }

    private func startPlayback(
        selection initialSelection: MediaPlaybackSelection?,
        settings: MediaPlaybackSettings?
    ) async -> Bool {
        isLoading = true

        let sessionID = UUID().uuidString
        playbackFailure = nil
        activeSelection = nil
        playbackSessionID = sessionID
        didCompletePlayback = false
        didRetryPlayback = false
        currentResumeOffset = nil
        let controller = playbackController ?? PlaybackSessionController()
        playbackController = controller
        let playerViewController = presentPlayerViewController(controller, isLoading: true)

        do {
            let selection: MediaPlaybackSelection?
            if let settings {
                let options = try await rememberedPlaybackOptions()
                selection = playbackSelection(for: settings, options: options)
            } else {
                selection = initialSelection
            }
            activeSelection = selection
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
            load(controller, resource: resource)
            if let playerViewController,
               presentedPlayerController === playerViewController {
                playerViewController.setLoading(false)
            } else {
                presentPlayerViewController(controller)
            }
            isLoading = false
            return true
        } catch {
            guard playbackController === controller else {
                isLoading = false
                return false
            }
            failPlaybackStart(controller, failure: PlaybackFailure(error))
            return false
        }
    }

    private func rememberedPlaybackOptions() async throws -> MediaPlaybackOptions? {
        if let playbackOptions {
            return playbackOptions
        }

        let options = try await model.playbackOptions(for: id)
        playbackOptions = options
        return options
    }

    private func playbackSelection(
        for settings: MediaPlaybackSettings,
        options: MediaPlaybackOptions?
    ) -> MediaPlaybackSelection {
        guard let options else {
            return MediaPlaybackSelection(
                quality: settings.quality,
                audioID: settings.audioID,
                subtitleID: settings.subtitleID
            )
        }

        let availableQualities = [.automatic] + options.qualityOptions
        return MediaPlaybackSelection(
            quality: availableQualities.contains(settings.quality) ? settings.quality : .automatic,
            audioID: restoredTrackID(
                settings.audioID,
                options: options.audioOptions,
                defaultID: options.selectedAudioID
            ),
            subtitleID: restoredTrackID(
                settings.subtitleID,
                options: options.subtitleOptions,
                defaultID: options.selectedSubtitleID
            ),
            defaultAudioID: options.selectedAudioID,
            defaultSubtitleID: options.selectedSubtitleID
        )
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
            autoplay: autoplay,
            onTimelineEvent: reportTimeline(state:time:duration:),
            onPlaybackEnded: playbackEnded(time:duration:),
            onRecoveryNeeded: handleRecovery(resumeOffset:error:),
            onNavigationNeeded: navigationHandler
        )
    }

    @discardableResult
    private func presentPlayerViewController(
        _ playbackController: PlaybackSessionController,
        isLoading: Bool = false
    ) -> StockPlayerViewController? {
        if let controller = presentedPlayerController, controller.view.window != nil {
            controller.configure(
                to: playbackController,
                onPictureInPictureChanged: pictureInPictureChanged
            )
            controller.setLoading(isLoading)
            return controller
        }

        presentedPlayerController?.clearDismissHandler()
        guard let presenter = rootPresenter() else { return nil }

        let controller = StockPlayerViewController(
            playbackController: playbackController,
            onPictureInPictureChanged: pictureInPictureChanged,
            onDismiss: stopPlayback
        )
        controller.setLoading(isLoading)
        presentedPlayerController = controller
        presenter.present(controller, animated: true)
        return controller
    }

    private func failPlaybackStart(
        _ playbackController: PlaybackSessionController,
        failure: PlaybackFailure
    ) {
        let playerViewController = presentedPlayerController
        playerViewController?.clearDismissHandler()
        presentedPlayerController = nil
        playbackController.stop()
        self.playbackController = nil
        isLoading = false

        guard let playerViewController else {
            playbackFailure = failure
            return
        }

        playerViewController.dismiss(animated: true) {
            playbackFailure = failure
            onPlaybackDismissed()
        }
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
            try await fetchPlaybackOptions()
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
        guard let settings = model.playbackSettings(for: id) else {
            draftQuality = .automatic
            draftAudioID = playbackOptions?.selectedAudioID
            draftSubtitleID = playbackOptions?.selectedSubtitleID
            return
        }

        draftQuality = qualityOptions.contains(settings.quality) ? settings.quality : .automatic
        draftAudioID = restoredTrackID(
            settings.audioID,
            options: playbackOptions?.audioOptions ?? [],
            defaultID: playbackOptions?.selectedAudioID
        )
        draftSubtitleID = restoredTrackID(
            settings.subtitleID,
            options: playbackOptions?.subtitleOptions ?? [],
            defaultID: playbackOptions?.selectedSubtitleID
        )
    }

    private func restoredTrackID(
        _ storedID: String?,
        options: [MediaPlaybackOption],
        defaultID: String?
    ) -> String? {
        guard let storedID else { return nil }
        return options.contains(where: { $0.id == storedID }) ? storedID : defaultID
    }

    private var draftPlaybackSelection: MediaPlaybackSelection {
        MediaPlaybackSelection(
            quality: draftQuality,
            audioID: draftAudioID,
            subtitleID: draftSubtitleID,
            defaultAudioID: playbackOptions?.selectedAudioID,
            defaultSubtitleID: playbackOptions?.selectedSubtitleID
        )
    }

    private func stopPlayback() {
        seekTask?.cancel()
        recoveryTask?.cancel()
        seekTask = nil
        recoveryTask = nil
        let controller = playbackController
        presentedPlayerController = nil

        let time = max(controller?.currentTimeMilliseconds ?? 0, currentResumeOffset ?? 0)
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

        let resumeOffset = savedTime > 0
            ? savedTime
            : currentResumeOffset ?? item.resumeOffsetMilliseconds ?? 0
        guard let previousController = playbackController else { return }
        let previousSessionID = activeRemoteSessionID
        currentResumeOffset = resumeOffset
        activeRemoteSessionID = nil
        previousController.prepareForRecovery()
        model.stopPlaybackSession(for: id, sessionID: previousSessionID)
        presentedPlayerController?.setLoading(true)
        recoveryTask?.cancel()
        recoveryTask = Task {
            isLoading = true
            defer { isLoading = false }

            guard !Task.isCancelled, playbackController === previousController else { return }

            do {
                let newSessionID = UUID().uuidString
                let resource = try await model.playbackURL(
                    for: id,
                    selection: activeSelection,
                    sessionID: newSessionID,
                    offsetMilliseconds: resumeOffset
                )
                guard !Task.isCancelled, playbackController === previousController else {
                    model.stopPlaybackSession(for: id, sessionID: resource.remoteSessionID)
                    return
                }
                playbackSessionID = newSessionID
                currentResumeOffset = resumeOffset
                load(previousController, resource: resource)
                presentPlayerViewController(previousController)
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
        if state == .playing {
            currentResumeOffset = nil
        }
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
    let isOffline: Bool
    let error: String?
    let qualityOptions: [MediaPlaybackQuality]
    let defaultResolutionTitle: String
    let audioOptions: [MediaPlaybackOption]
    let subtitleOptions: [MediaPlaybackOption]
    let selectedAudioID: String?
    let selectedSubtitleID: String?
    let defaultVideoTranscoding: String?
    let defaultAudioTranscoding: String?
    @Binding var draftQuality: MediaPlaybackQuality
    @Binding var draftAudioID: String?
    @Binding var draftSubtitleID: String?
    let playTitle: String
    let onClose: () -> Void
    let onPlay: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if PlatformMetadata.isPhone {
            content
                .fullScreenCover(isPresented: $isPresented) {
                    ZStack {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()

                        playbackDialog
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .shadow(color: .black.opacity(0.35), radius: 28, y: 12)
                    }
                    .presentationBackground(.clear)
                }
        } else {
            content
                .sheet(isPresented: $isPresented) {
                    playbackDialog
                }
        }
    }

    private var playbackDialog: some View {
        PlaybackOptionsDialog(
            isLoading: isLoading,
            isOffline: isOffline,
            error: error,
            qualityOptions: qualityOptions,
            defaultResolutionTitle: defaultResolutionTitle,
            audioOptions: audioOptions,
            subtitleOptions: subtitleOptions,
            selectedAudioID: selectedAudioID,
            selectedSubtitleID: selectedSubtitleID,
            defaultVideoTranscoding: defaultVideoTranscoding,
            defaultAudioTranscoding: defaultAudioTranscoding,
            draftQuality: $draftQuality,
            draftAudioID: $draftAudioID,
            draftSubtitleID: $draftSubtitleID,
            playTitle: playTitle,
            onClose: onClose,
            onPlay: onPlay
        )
    }
}

private struct PlaybackOptionsDialog: View {
    let isLoading: Bool
    let isOffline: Bool
    let error: String?
    let qualityOptions: [MediaPlaybackQuality]
    let defaultResolutionTitle: String
    let audioOptions: [MediaPlaybackOption]
    let subtitleOptions: [MediaPlaybackOption]
    let selectedAudioID: String?
    let selectedSubtitleID: String?
    let defaultVideoTranscoding: String?
    let defaultAudioTranscoding: String?
    @Binding var draftQuality: MediaPlaybackQuality
    @Binding var draftAudioID: String?
    @Binding var draftSubtitleID: String?
    let playTitle: String
    let onClose: () -> Void
    let onPlay: () -> Void

    @FocusState private var isPlayFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Play Options")
                .font(dialogTitleFont)

            VStack(spacing: 16) {
                playbackMenu(title: title(for: draftQuality), systemImage: "display") {
                    ForEach(qualityOptions) { quality in
                        Button {
                            draftQuality = quality
                        } label: {
                            PlaybackOptionsMenuItem(
                                title: title(for: quality),
                                isSelected: quality == draftQuality
                            )
                        }
                    }
                }

                playbackMenu(title: audioTitle, systemImage: "speaker.wave.3.fill") {
                    ForEach(audioOptions) { option in
                        Button {
                            draftAudioID = option.id
                        } label: {
                            PlaybackOptionsMenuItem(
                                title: trackTitle(option, defaultID: selectedAudioID),
                                isSelected: option.id == draftAudioID
                            )
                        }
                    }

                    Button {
                        draftAudioID = nil
                    } label: {
                        PlaybackOptionsMenuItem(
                            title: noneTitle(defaultID: selectedAudioID),
                            isSelected: draftAudioID == nil
                        )
                    }
                }

                playbackMenu(title: subtitleTitle, systemImage: "captions.bubble") {
                    ForEach(subtitleOptions) { option in
                        Button {
                            draftSubtitleID = option.id
                        } label: {
                            PlaybackOptionsMenuItem(
                                title: trackTitle(option, defaultID: selectedSubtitleID),
                                isSelected: option.id == draftSubtitleID
                            )
                        }
                    }

                    Button {
                        draftSubtitleID = nil
                    } label: {
                        PlaybackOptionsMenuItem(
                            title: noneTitle(defaultID: selectedSubtitleID),
                            isSelected: draftSubtitleID == nil
                        )
                    }
                }
            }

            transcodingBlock

            if let error {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            VStack(spacing: 14) {
                Button(action: play) {
                    Group {
                        if isLoading {
                            ProgressView()
                        } else {
                            Label(playTitle, systemImage: "play.fill")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(MediaGlassButtonStyle(horizontalPadding: 24, verticalPadding: 16))
                .focused($isPlayFocused)
                .disabled(isOffline || isLoading)

                Button(role: .cancel, action: cancel) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MediaGlassButtonStyle(horizontalPadding: 24, verticalPadding: 16))
            }
        }
        .padding(34)
        .foregroundStyle(AppTheme.primaryText)
        .frame(width: dialogWidth)
        .background(AppTheme.backgroundTop)
        .presentationSizing(.fitted)
        .task {
            isPlayFocused = true
        }
    }

    private var dialogTitleFont: Font {
#if os(tvOS)
        .system(size: 28, weight: .bold)
#else
        .title2.bold()
#endif
    }

    private func cancel() {
#if targetEnvironment(macCatalyst)
        dismissPresentation(completion: onClose)
#else
        onClose()
#endif
    }

    private func play() {
        dismissPresentation(completion: onPlay)
    }

    private func dismissPresentation(completion: @escaping () -> Void) {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        var controller = window?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        guard let controller, controller.presentingViewController != nil else {
            completion()
            return
        }
        controller.dismiss(animated: false, completion: completion)
    }

    private var audioTitle: String {
        guard let draftAudioID,
              let option = audioOptions.first(where: { $0.id == draftAudioID }) else {
            return noneTitle(defaultID: selectedAudioID)
        }
        return trackTitle(option, defaultID: selectedAudioID)
    }

    private var subtitleTitle: String {
        guard let draftSubtitleID,
              let option = subtitleOptions.first(where: { $0.id == draftSubtitleID }) else {
            return noneTitle(defaultID: selectedSubtitleID)
        }
        return trackTitle(option, defaultID: selectedSubtitleID)
    }

    private func title(for quality: MediaPlaybackQuality) -> String {
        quality == .automatic ? defaultResolutionTitle : quality.title
    }

    private var dialogWidth: CGFloat {
#if os(tvOS)
        720
#else
        guard PlatformMetadata.isPhone else { return 640 }
        let screenWidth = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.bounds.width }
            .first ?? 390
        return min(screenWidth - 24, 640)
#endif
    }

    private var transcodingBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            transcodingLine(label: "Video transcoding", value: videoTranscoding)
            transcodingLine(label: "Audio transcoding", value: audioTranscoding)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surfaceFill)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var videoTranscoding: String? {
        draftQuality == .automatic
            ? defaultVideoTranscoding
            : "H.264 at \(draftQuality.title)"
    }

    private var audioTranscoding: String? {
        draftAudioID.flatMap { audioID in
            audioOptions.first(where: { $0.id == audioID })?.transcodingTitle
        } ?? (draftAudioID == selectedAudioID ? defaultAudioTranscoding : nil)
    }

    private func transcodingLine(label: String, value: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(label):")
            Text(value ?? "None")
                .foregroundStyle(value == nil ? AppTheme.secondaryText : .orange)
        }
        .font(transcodingTextFont)
    }

    private var transcodingTextFont: Font {
#if os(tvOS)
        .system(size: 18)
#else
        .callout
#endif
    }

    private func trackTitle(_ option: MediaPlaybackOption, defaultID: String?) -> String {
        option.id == defaultID ? "\(option.title) (Default)" : option.title
    }

    private func noneTitle(defaultID: String?) -> String {
        defaultID == nil ? "None (Default)" : "None"
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
        .buttonStyle(MediaGlassButtonStyle(horizontalPadding: 24, verticalPadding: 16))
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
    private let loadingIndicator = UIActivityIndicatorView(style: .large)

    private var didDismiss = false
    private var isPictureInPictureActive = false
    private var isLoading = false
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
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = .white
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        updateLoadingIndicator()
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

    func setLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
        guard isViewLoaded else { return }
        updateLoadingIndicator()
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

    private func updateLoadingIndicator() {
        if isLoading {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
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
