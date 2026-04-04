import SwiftUI

struct JellyfinSettingsView: View {
    @ObservedObject var model: AppModel
    @Binding var path: [AppRoute]

    var body: some View {
        ServerManagementPanel(model: model, path: $path, providerName: "Jellyfin")
        .navigationTitle("Manage Jellyfin")
    }
}
