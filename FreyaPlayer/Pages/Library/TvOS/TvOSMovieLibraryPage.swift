import SwiftUI

#if os(tvOS)
struct MovieLibraryPage: View {
    @ObservedObject var model: AppModel
    let library: LibraryReference
    @Binding var path: [AppRoute]

    var body: some View {
        TvOSLibraryPageContent(model: model, library: library, path: $path)
    }
}
#endif
