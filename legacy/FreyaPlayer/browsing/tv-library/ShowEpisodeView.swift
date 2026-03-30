import SwiftUI

struct ShowEpisodeView: View {
    let title: String

    var body: some View {
        FeatureStubView(
            title: title,
            message: "Episode details and playback entry will live here."
        )
    }
}
