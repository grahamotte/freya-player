import SwiftUI

struct ServerManagementServerSection: View {
    let server: ConnectedServer
    let cacheSizeText: String
    let onClearCache: () -> Void
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
            Button("Clear Cache (\(cacheSizeText))") {
                onClearCache()
            }
            .buttonStyle(MediaGlassButtonStyle())

            Button("Deactivate") {
                onDeactivate()
            }
            .buttonStyle(MediaGlassButtonStyle(tint: .red))
        }
    }
}
