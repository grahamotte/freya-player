import SwiftUI

#if os(tvOS)
struct PlexSetupPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        PlexSetupContent(model: model)
    }
}
#endif
