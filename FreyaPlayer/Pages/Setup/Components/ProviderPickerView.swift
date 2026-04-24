import SwiftUI

struct ProviderPickerView: View {
    var body: some View {
        VStack(spacing: 56) {
            Image("FreyaLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 300, height: 300)

            HStack(spacing: 72) {
                NavigationLink(value: AppRoute.jellyfinSetup) {
                    serviceButton(title: "Jellyfin", systemImage: "square.stack.3d.up.fill")
                }
                .buttonStyle(MediaGlassButtonStyle(horizontalPadding: 72, verticalPadding: 44))

                NavigationLink(value: AppRoute.plexSetup) {
                    serviceButton(title: "Plex", systemImage: "play.rectangle.fill")
                }
                .buttonStyle(MediaGlassButtonStyle(horizontalPadding: 72, verticalPadding: 44))
            }
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
    }

    private func serviceButton(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.title3.weight(.semibold))
    }
}
