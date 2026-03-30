import AVKit
import SwiftUI

struct MediaPlayButton: View {
    @ObservedObject var model: AppModel
    let id: MediaPlaybackID

    @State private var isLoading = false
    @State private var playbackError: String?
    @State private var player: AVPlayer?
    @State private var isShowingPlayer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            if let playbackError {
                Text(playbackError)
                    .foregroundStyle(.secondary)
            }
        }
        .fullScreenCover(isPresented: $isShowingPlayer, onDismiss: stopPlayback) {
            if let player {
                VideoPlayer(player: player)
                    .background(Color.black)
                    .ignoresSafeArea()
                    .onAppear {
                        player.play()
                    }
            }
        }
    }

    private func startPlayback() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let url = try await model.playbackURL(for: id)
            playbackError = nil
            player = AVPlayer(url: url)
            isShowingPlayer = true
        } catch {
            playbackError = "Playback isn't ready right now."
        }
    }

    private func stopPlayback() {
        player?.pause()
        player = nil
    }
}
