import SwiftUI
import AVFAudio

@main
struct FreyaPlayerApp: App {
    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    }

    var body: some Scene {
        WindowGroup {
            AppView()
        }
    }
}
