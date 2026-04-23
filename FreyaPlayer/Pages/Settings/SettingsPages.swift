import SwiftUI

struct PlexSettingsPage: View {
    @ObservedObject var model: AppModel
    @Binding var path: [AppRoute]

    var body: some View {
        ServerManagementPanel(model: model, path: $path)
    }
}

struct JellyfinSettingsPage: View {
    @ObservedObject var model: AppModel
    @Binding var path: [AppRoute]

    var body: some View {
        ServerManagementPanel(model: model, path: $path)
    }
}
