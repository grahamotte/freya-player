import SwiftUI

struct JellyfinSetupContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var serverProtocol = "https"
    @State private var address = ""
    @State private var port = "443"
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                MediaProviderLabel(providerID: .jellyfin)
                    .font(.title3.weight(.semibold))

                serverAddressLayout {
                    setupField("Protocol") {
                        Picker("Protocol", selection: $serverProtocol) {
                            Text("HTTP").tag("http")
                            Text("HTTPS").tag("https")
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .onChange(of: serverProtocol) { _, scheme in
                            port = scheme == "https" ? "443" : "8096"
                        }
                    }

                    setupField("Address") {
                        TextField("64.23.154.109", text: $address)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    setupField("Port") {
                        TextField(serverProtocol == "https" ? "443" : "8096", text: $port)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .frame(width: usesCompactLayout ? nil : 140)
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
                    if let serverURL {
                        model.connectJellyfin(
                            serverURL: serverURL,
                            username: username,
                            password: password
                        )
                    }
                }
                .buttonStyle(MediaGlassButtonStyle())
                .disabled(serverURL == nil || username.isEmpty || password.isEmpty)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(usesCompactLayout ? 20 : 28)
            .background(PanelBackground())

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(MediaGlassButtonStyle())

            Spacer()
        }
        .padding(usesCompactLayout ? 16 : 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
        .task {
            model.prepareJellyfinSetup()
        }
    }

    private var serverURL: String? {
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = port.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty, let port = Int(port), 1...65_535 ~= port else { return nil }
        return "\(serverProtocol)://\(address):\(port)"
    }

    private var usesCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    private func serverAddressLayout<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let layout = usesCompactLayout
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
            : AnyLayout(HStackLayout(alignment: .bottom, spacing: 18))
        return layout {
            content()
        }
    }

    private func setupField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)

            if PlatformMetadata.isTV {
                content()
            } else {
                content()
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(AppTheme.surfaceFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}
