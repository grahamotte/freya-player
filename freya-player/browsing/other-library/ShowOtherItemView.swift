import SwiftUI

struct ShowOtherItemView: View {
    let title: String

    var body: some View {
        FeatureStubView(
            title: title,
            message: "Details for non-movie, non-series items will live here."
        )
    }
}
