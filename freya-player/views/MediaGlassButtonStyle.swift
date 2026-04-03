import SwiftUI

struct MediaGlassButtonStyle: ButtonStyle {
    var tint: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        MediaGlassButtonBody(configuration: configuration, tint: tint)
    }
}

private struct MediaGlassButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let tint: Color?
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isFocused ? .black : .white)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 36, style: .continuous)
            .fill(isFocused ? Color.white : baseColor.opacity(tint == nil ? 0.12 : 0.18))
            .overlay {
                if !isFocused {
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .stroke(baseColor.opacity(tint == nil ? 0.28 : 0.4), lineWidth: 1)
                }
            }
    }

    private var baseColor: Color {
        tint ?? .white
    }
}
