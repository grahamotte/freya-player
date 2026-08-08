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
        Group {
            if PlatformMetadata.isPhone {
                VStack(alignment: .leading, spacing: 10) {
                    titleText
                    HStack(spacing: 16) {
                        rowButtons
                        Spacer(minLength: 0)
                        eyeButton
                    }
                }
            } else {
                HStack(spacing: 16) {
                    rowButtons
                    titleText
                    Spacer(minLength: 0)
                    eyeButton
                }
            }
        }
        .padding(.horizontal, PlatformMetadata.isPhone ? 12 : 18)
        .padding(.vertical, 16)
        .background(rowBackground)
    }

    private var titleText: some View {
        Text(title)
            .font(.title3.weight(.medium))
            .lineLimit(1)
            .strikethrough(isHidden, color: AppTheme.secondaryText)
            .foregroundStyle(isHidden ? AppTheme.secondaryText : AppTheme.primaryText)
    }

    private var rowButtons: some View {
        Group {
            Button(action: onMoveUp) {
                rowIcon("arrow.up", iconSize: 24, frameSize: 24, textStyle: .headline)
            }
            .buttonStyle(rowButtonStyle)
            .disabled(!canMoveUp)

            Button(action: onMoveDown) {
                rowIcon("arrow.down", iconSize: 24, frameSize: 24, textStyle: .headline)
            }
            .buttonStyle(rowButtonStyle)
            .disabled(!canMoveDown)
        }
    }

    private var eyeButton: some View {
        Button(action: onToggleVisibility) {
            rowIcon(
                isHidden ? "eye.slash" : "eye",
                iconSize: visibilityIconSize,
                frameSize: 24,
                textStyle: .subheadline
            )
        }
        .buttonStyle(rowButtonStyle)
    }

    private var rowButtonStyle: MediaGlassButtonStyle {
        MediaGlassButtonStyle(horizontalPadding: 14, verticalPadding: 14)
    }

    private var visibilityIconSize: CGFloat {
        PlatformMetadata.isTV ? 16 : 18
    }

    private func rowIcon(
        _ systemName: String,
        iconSize: CGFloat,
        frameSize: CGFloat,
        textStyle: Font.TextStyle
    ) -> some View {
        Image(systemName: systemName)
            .font(.system(textStyle, weight: .semibold))
            .frame(width: iconSize, height: iconSize)
            .frame(width: frameSize, height: frameSize)
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
