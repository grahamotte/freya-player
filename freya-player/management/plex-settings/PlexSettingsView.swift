import SwiftUI

struct PlexSettingsView: View {
    @ObservedObject var model: AppModel
    @Binding var path: [AppRoute]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                Text("Plex Server")
                    .font(.title3.weight(.semibold))

                Text(model.connectedServer?.serverName ?? "Unknown Server")
                    .font(.title2.weight(.semibold))

                Text(model.connectedServer?.accountName ?? "Plex")
                    .foregroundStyle(.secondary)

                Button("Deactivate Server", role: .destructive) {
                    model.disconnectCurrentServer()
                    path.removeAll()
                }

                Button("Back") {
                    dismiss()
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(28)
            .background(PanelBackground())

            Spacer()
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
        .navigationTitle("Manage Plex")
    }
}
