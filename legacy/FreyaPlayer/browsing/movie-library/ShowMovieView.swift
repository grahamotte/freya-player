import SwiftUI

struct ShowMovieView: View {
    let title: String

    var body: some View {
        FeatureStubView(
            title: title,
            message: "Movie details and playback entry will live here."
        )
    }
}
