import SwiftUI

struct JellyfinSetupContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                Label("Jellyfin", systemImage: "square.stack.3d.up.fill")
                    .font(.title3.weight(.semibold))

                setupField("Server URL") {
                    TextField("Server URL", text: $serverURL)
                }

                setupField("Username") {
                    TextField("Username", text: $username)
                }

                setupField("Password") {
                    SecureField("Password", text: $password)
                }

                if case .failed(let message) = model.connectionState {
                    Text(message)
                        .foregroundStyle(.secondary)
                } else if case .connecting(let message) = model.connectionState {
                    ProgressView(message)
                }

                Button("Connect") {
                    model.connectJellyfin(
                        serverURL: serverURL,
                        username: username,
                        password: password
                    )
                }
                .disabled(serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || username.isEmpty || password.isEmpty)
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
        .navigationTitle("Jellyfin")
        .task {
            model.prepareJellyfinSetup()
        }
    }

    private func setupField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
