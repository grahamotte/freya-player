import SwiftUI

struct PlexSetupContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingPlexNotice = false

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                Label("Plex", systemImage: "play.rectangle.fill")
                    .font(.title3.weight(.semibold))

                switch model.connectionState {
                case .checking:
                    ProgressView("Checking saved Plex connection...")

                case .signedOut(let message):
                    Text(message)
                        .foregroundStyle(AppTheme.secondaryText)

                    Button("Connect With Plex") {
                        model.startPlexLogin()
                    }
                    .buttonStyle(MediaGlassButtonStyle())

                case .connecting(let message):
                    if let code = model.plexLinkCode {
                        Text("Visit this link in your browser")
                            .foregroundStyle(AppTheme.secondaryText)

                        Text("plex.tv/link")
                            .font(.headline)

                        Text("and enter this code")
                            .foregroundStyle(AppTheme.secondaryText)

                        Text(code)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .monospaced()
                    }

                    Text(message)
                        .foregroundStyle(AppTheme.secondaryText)

                case .failed(let message):
                    Text(message)
                        .foregroundStyle(AppTheme.secondaryText)

                    Button("Try Again") {
                        model.startPlexLogin()
                    }
                    .buttonStyle(MediaGlassButtonStyle())

                case .connected:
                    ProgressView("Loading your server...")
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(28)
            .background(PanelBackground())

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(MediaGlassButtonStyle())

            Spacer()
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
        .task {
            showingPlexNotice = true
        }
        .alert("Before You Use Plex", isPresented: $showingPlexNotice) {
            Button("I Understand, Continue") {
                model.preparePlexSetup()
            }

            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Plex depends on plex.tv services for sign-in and server discovery, so using Plex means communicating to more than your own server.\n\nPlex may record login, connection, and watch history activity. Freya Player is committed to never tracking you, but we have no control or insight into what Plex collects while acting between this app and your server.\n\nIf Jellyfin is an option for you, we strongly recommend switching to it.")
        }
        .onDisappear {
            model.cancelPlexSetup()
        }
    }
}
