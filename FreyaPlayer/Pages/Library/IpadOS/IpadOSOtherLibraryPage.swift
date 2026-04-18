import SwiftUI

#if os(iOS)
struct OtherLibraryPage: View {
    @ObservedObject var model: AppModel
    let library: LibraryReference
    @Binding var path: [AppRoute]

    var body: some View {
        IpadLibraryPageContent(model: model, library: library)
    }
}
#endif
