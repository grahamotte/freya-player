import SwiftUI

struct MediaGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MediaGlassButtonBody(configuration: configuration)
    }
}

private struct MediaGlassButtonBody: View {
    let configuration: ButtonStyle.Configuration
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
            .fill(isFocused ? Color.white : Color.white.opacity(0.12))
            .overlay {
                if !isFocused {
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                }
            }
    }
}
