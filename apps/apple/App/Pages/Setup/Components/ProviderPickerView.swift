import SwiftUI

struct ProviderPickerView: View {
    var body: some View {
        VStack(spacing: 56) {
            Image("FreyaLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 300, height: 300)

            if PlatformMetadata.isPhone {
                VStack(spacing: 24) {
                    serviceButtons
                }
            } else {
                HStack(spacing: 72) {
                    serviceButtons
                }
            }

            NavigationLink(value: AppRoute.about) {
                Label("About", systemImage: "info.circle")
                    .font(.headline)
            }
            .buttonStyle(MediaGlassButtonStyle())
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
    }

    private var serviceButtons: some View {
        Group {
            NavigationLink(value: AppRoute.jellyfinSetup) {
                Label("Jellyfin", systemImage: "square.stack.3d.up.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MediaGlassButtonStyle(horizontalPadding: 72, verticalPadding: 44))

            NavigationLink(value: AppRoute.plexSetup) {
                Label("Plex", systemImage: "play.rectangle.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MediaGlassButtonStyle(horizontalPadding: 72, verticalPadding: 44))
        }
    }
}
