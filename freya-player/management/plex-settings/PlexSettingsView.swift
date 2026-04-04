import SwiftUI

struct PlexSettingsView: View {
    @ObservedObject var model: AppModel
    @Binding var path: [AppRoute]

    var body: some View {
        ServerManagementPanel(model: model, path: $path, providerName: "Plex")
        .navigationTitle("Manage Plex")
    }
}
