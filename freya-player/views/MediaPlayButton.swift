import AVKit
import SwiftUI

struct MediaPlayButton: View {
    @ObservedObject var model: AppModel
    let id: MediaPlaybackID

    @FocusState private var focusedControl: FocusedControl?

    @State private var isLoading = false
    @State private var isLoadingOptions = false
    @State private var playbackOptions: MediaPlaybackOptions?
    @State private var playbackError: String?
    @State private var selectedAudioID: String?
    @State private var selectedSubtitleID: String?
    @State private var player: AVPlayer?
    @State private var isShowingPlayer = false

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
                        Text("Play")
                            .frame(minWidth: 140)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
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
                    .buttonStyle(.bordered)
                    .buttonBorderShape(focusedControl == .audio ? .capsule : .circle)
                    .controlSize(.large)
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
                    .buttonStyle(.bordered)
                    .buttonBorderShape(focusedControl == .subtitle ? .capsule : .circle)
                    .controlSize(.large)
                    .focused($focusedControl, equals: .subtitle)
                    .disabled(isLoading || isLoadingOptions)
                }
            }

            if let playbackError {
                Text(playbackError)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: id) {
            await refreshPlaybackOptions()
        }
        .fullScreenCover(isPresented: $isShowingPlayer, onDismiss: stopPlayback) {
            if let player {
                StockPlayerView(player: player)
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

            let url = try await model.playbackURL(for: id, selection: playbackSelection)
            playbackError = nil
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
        player?.pause()
        player = nil
    }

    private enum FocusedControl {
        case audio
        case subtitle
    }
}

private struct StockPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
        player.play()
    }
}
