import SwiftUI

struct ServerManagementPanel: View {
    @ObservedObject var model: AppModel
    @Binding var path: [AppRoute]
    @Environment(\.dismiss) private var dismiss

    let providerName: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("\(providerName) Server")
                    .font(.title3.weight(.semibold))

                Text(model.connectedServer?.serverName ?? "Unknown Server")
                    .font(.title2.weight(.semibold))

                Text(model.connectedServer?.accountName ?? providerName)
                    .foregroundStyle(.secondary)

                if let server = model.connectedServer {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Libraries")
                            .font(.headline)

                        VStack(spacing: 14) {
                            ForEach(Array(server.libraries.enumerated()), id: \.element.id) { index, library in
                                LibraryOrderRow(
                                    title: library.title,
                                    isHidden: library.isHidden,
                                    canMoveUp: index > 0,
                                    canMoveDown: index < server.libraries.count - 1,
                                    toggleVisibility: {
                                        model.setLibraryHidden(!library.isHidden, at: index)
                                    },
                                    moveUp: { model.moveLibrary(at: index, by: -1) },
                                    moveDown: { model.moveLibrary(at: index, by: 1) }
                                )
                            }
                        }
                    }
                }

                HStack(spacing: 18) {
                    Button("Deactivate Server") {
                        model.disconnectCurrentServer()
                        path.removeAll()
                    }
                    .buttonStyle(MediaGlassButtonStyle(tint: .red))

                    Button("Back") {
                        dismiss()
                    }
                    .buttonStyle(MediaGlassButtonStyle())
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: 860, alignment: .leading)
            .padding(32)
            .background(PanelBackground())
            .padding(48)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
    }
}

private struct LibraryOrderRow: View {
    let title: String
    let isHidden: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let toggleVisibility: () -> Void
    let moveUp: () -> Void
    let moveDown: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: toggleVisibility) {
                Image(systemName: isHidden ? "eye.slash" : "eye")
                    .font(.title3.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(MediaGlassButtonStyle(horizontalPadding: 18, verticalPadding: 18))

            Button(action: moveUp) {
                Image(systemName: "arrow.up")
                    .font(.title3.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(MediaGlassButtonStyle(horizontalPadding: 18, verticalPadding: 18))
            .disabled(!canMoveUp)

            Button(action: moveDown) {
                Image(systemName: "arrow.down")
                    .font(.title3.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(MediaGlassButtonStyle(horizontalPadding: 18, verticalPadding: 18))
            .disabled(!canMoveDown)

            Text(title)
                .font(.title3.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(isHidden ? .secondary : .primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(rowBackground)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            }
    }
}
