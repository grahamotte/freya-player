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

                if PlatformMetadata.isPhone {
                    VStack(alignment: .leading, spacing: 12) {
                        actionButtons
                    }
                } else {
                    HStack(spacing: 12) {
                        actionButtons
                    }
                }
            }
        }
    }

    private var actionButtons: some View {
        Group {
            Button("Deactivate") {
                onDeactivate()
            }
            .buttonStyle(MediaGlassButtonStyle(tint: .red))
        }
    }
}
