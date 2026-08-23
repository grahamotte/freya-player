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
    @FocusState private var focusedField: Field?

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                MediaProviderLabel(providerID: .jellyfin)
                    .font(sectionTitleFont)

                serverAddressLayout {
                    setupTextField(
                        "Protocol",
                        text: $serverProtocol,
                        placeholder: "https",
                        field: .protocol
                    )
                    .frame(width: usesCompactLayout ? nil : shortFieldWidth)

                    setupTextField(
                        "Address",
                        text: $address,
                        placeholder: "64.23.154.109",
                        field: .address
                    )
                    .frame(maxWidth: .infinity)

                    setupTextField(
                        "Port",
                        text: $port,
                        placeholder: serverProtocol == "https" ? "443" : "8096",
                        field: .port
                    )
                    .frame(width: usesCompactLayout ? nil : shortFieldWidth)
                }

                setupTextField(
                    "Username",
                    text: $username,
                    placeholder: "Username",
                    field: .username
                )

                setupTextField(
                    "Password",
                    text: $password,
                    placeholder: "Password",
                    field: .password
                )

                if case .failed(let message) = model.connectionState {
                    Text(message)
                        .foregroundStyle(AppTheme.secondaryText)
                } else if case .connecting(let message) = model.connectionState {
                    ProgressView(message)
                }

                HStack(spacing: 16) {
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

                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(MediaGlassButtonStyle())
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(usesCompactLayout ? 20 : 28)
            .background(PanelBackground())

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
        let serverProtocol = serverProtocol.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = port.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            serverProtocol == "http" || serverProtocol == "https",
            !address.isEmpty,
            let port = Int(port),
            1...65_535 ~= port
        else { return nil }
        return "\(serverProtocol)://\(address):\(port)"
    }

    private var usesCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var sectionTitleFont: Font {
        .title3.weight(.semibold)
    }

    private var fieldLabelFont: Font {
        .footnote.weight(.semibold)
    }

    private var shortFieldWidth: CGFloat {
        PlatformMetadata.isTV ? 160 : 120
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
                .font(fieldLabelFont)
                .foregroundStyle(AppTheme.secondaryText)

            content()
        }
    }

    @ViewBuilder
    private func setupTextField(
        _ title: String,
        text: Binding<String>,
        placeholder: String,
        field: Field
    ) -> some View {
        #if os(tvOS)
            let isFocused = focusedField == field
            let prompt = Text(title)
                .foregroundStyle(isFocused ? Color.black : AppTheme.secondaryText)

            setupField(title) {
                TextField(title, text: text, prompt: prompt)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: field)
                    .foregroundStyle(isFocused ? Color.black : AppTheme.primaryText)
                    .controlSize(.large)
            }
        #else
            let isFocused = focusedField == field
            let prompt = Text(placeholder)
                .foregroundStyle(Color.black.opacity(0.6))

            setupField(title) {
                TextField(title, text: text, prompt: prompt)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: field)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        Color.white.opacity(0.86),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                isFocused ? Color.accentColor : Color.black.opacity(0.2),
                                lineWidth: isFocused ? 2 : 1
                            )
                    }
                    .environment(\.colorScheme, .light)
            }
        #endif
    }

    private enum Field: Hashable {
        case `protocol`
        case address
        case port
        case username
        case password
    }
}
