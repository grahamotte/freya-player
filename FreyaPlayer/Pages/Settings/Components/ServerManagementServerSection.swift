import SwiftUI

struct ServerManagementServerSection: View {
    let server: ConnectedServer
    let onDeactivate: () -> Void

    var body: some View {
        ServerManagementSection("Server") {
            VStack(alignment: .leading, spacing: 14) {
                Text(server.serverName)
                    .font(.title3.weight(.semibold))

                Text("\(server.serverURL) (\(server.providerID.title))")
                    .foregroundStyle(AppTheme.secondaryText)

                Button("Deactivate") {
                    onDeactivate()
                }
                .buttonStyle(MediaGlassButtonStyle(tint: .red))
            }
        }
    }
}
