import SwiftUI

@main
struct FreyaPlayerApp: App {
    init() {
        PlaybackAudioSession.activate()
    }

    var body: some Scene {
        WindowGroup {
            AppView()
        }
        .macOSCommands()
    }
}
