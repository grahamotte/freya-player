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

                setupField("Server URL or Host") {
                    TextField("64.23.154.109 or server:8096", text: $serverURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                setupField("Username") {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                setupField("Password") {
                    SecureField("Password", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if case .failed(let message) = model.connectionState {
                    Text(message)
                        .foregroundStyle(AppTheme.secondaryText)
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
                .buttonStyle(MediaGlassButtonStyle())
                .disabled(serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || username.isEmpty || password.isEmpty)
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
            model.prepareJellyfinSetup()
        }
    }

    private func setupField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)

            content()
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(AppTheme.surfaceFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
