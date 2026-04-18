import SwiftUI

#if os(tvOS)
struct LibrariesPage: View {
    @ObservedObject var model: AppModel
    let server: ConnectedServer
    @Binding var path: [AppRoute]

    var body: some View {
        TvOSLibrariesPageContent(model: model, server: server, path: $path)
    }
}
#endif
