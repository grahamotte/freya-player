import SwiftUI

struct ServerManagementLibrariesSection: View {
    let libraries: [LibraryShelf]
    let onToggleVisibility: (Int, Bool) -> Void
    let onMoveLibrary: (Int, Int) -> Void

    var body: some View {
        ServerManagementSection("Libraries") {
            VStack(spacing: 14) {
                ForEach(Array(libraries.enumerated()), id: \.element.id) { index, library in
                    ServerManagementLibraryRow(
                        title: library.title,
                        isHidden: library.isHidden,
                        canMoveUp: index > 0,
                        canMoveDown: index < libraries.count - 1,
                        onToggleVisibility: {
                            onToggleVisibility(index, !library.isHidden)
                        },
                        onMoveUp: {
                            onMoveLibrary(index, -1)
                        },
                        onMoveDown: {
                            onMoveLibrary(index, 1)
                        }
                    )
                }
            }
        }
    }
}

private struct ServerManagementLibraryRow: View {
    let title: String
    let isHidden: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onToggleVisibility: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onMoveUp) {
                rowIcon("arrow.up")
            }
            .buttonStyle(rowButtonStyle)
            .disabled(!canMoveUp)

            Button(action: onMoveDown) {
                rowIcon("arrow.down")
            }
            .buttonStyle(rowButtonStyle)
            .disabled(!canMoveDown)

            Text(title)
                .font(.title3.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(isHidden ? AppTheme.secondaryText : AppTheme.primaryText)

            Spacer(minLength: 0)

            Button(action: onToggleVisibility) {
                rowIcon(isHidden ? "eye.slash" : "eye")
            }
            .buttonStyle(rowButtonStyle)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(rowBackground)
    }

    private var rowButtonStyle: MediaGlassButtonStyle {
        MediaGlassButtonStyle(horizontalPadding: 14, verticalPadding: 14)
    }

    private func rowIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.headline)
            .frame(width: 24, height: 24)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(AppTheme.subtleSurfaceFill)
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AppTheme.surfaceBorder, lineWidth: 1)
            }
    }
}
