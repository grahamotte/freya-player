import SwiftUI

struct PlexSetupContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

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
                        .foregroundStyle(.secondary)

                    Button("Connect With Plex") {
                        model.startPlexLogin()
                    }

                case .connecting(let message):
                    if let code = model.plexLinkCode {
                        Text("Visit this link in your browser")
                            .foregroundStyle(.secondary)

                        Text("plex.tv/link")
                            .font(.headline)

                        Text("and enter this code")
                            .foregroundStyle(.secondary)

                        Text(code)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .monospaced()
                    }

                    Text(message)
                        .foregroundStyle(.secondary)

                case .failed(let message):
                    Text(message)
                        .foregroundStyle(.secondary)

                    Button("Try Again") {
                        model.startPlexLogin()
                    }

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

            Spacer()
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
        .navigationTitle("Plex")
        .task {
            model.preparePlexSetup()
        }
    }
}
