import SwiftUI

struct MovieLibraryPage: View {
    @ObservedObject var model: AppModel
    let library: LibraryReference
    @Binding var path: [AppRoute]

    var body: some View {
        PlatformLibraryPageContent(model: model, library: library, path: $path)
    }
}
