import SwiftUI

#if os(tvOS)
struct JellyfinSetupPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        JellyfinSetupContent(model: model)
    }
}
#endif
