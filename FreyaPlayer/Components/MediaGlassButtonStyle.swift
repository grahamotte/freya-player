import SwiftUI

struct MediaGlassButtonStyle: ButtonStyle {
    var tint: Color? = nil
    var horizontalPadding: CGFloat = 28
    var verticalPadding: CGFloat = 16

    func makeBody(configuration: Configuration) -> some View {
        MediaGlassButtonBody(
            configuration: configuration,
            tint: tint,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding
        )
    }
}

private struct MediaGlassButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let tint: Color?
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    @Environment(\.isFocused) private var isFocused
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isFocused ? AppTheme.inverseText : AppTheme.primaryText)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.45)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 36, style: .continuous)
            .fill(isFocused ? AppTheme.primaryText : baseColor.opacity(tint == nil ? 0.12 : 0.18))
            .overlay {
                if !isFocused {
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .stroke(baseColor.opacity(tint == nil ? 0.28 : 0.4), lineWidth: 1)
                }
            }
    }

    private var baseColor: Color {
        tint ?? AppTheme.primaryText
    }
}
