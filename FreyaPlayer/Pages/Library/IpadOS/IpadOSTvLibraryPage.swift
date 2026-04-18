import SwiftUI

#if os(iOS)
struct TvLibraryPage: View {
    @ObservedObject var model: AppModel
    let library: LibraryReference
    @Binding var path: [AppRoute]

    var body: some View {
        IpadLibraryPageContent(model: model, library: library)
    }
}
#endif
