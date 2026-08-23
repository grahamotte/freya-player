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
                MediaProviderLabel(providerID: .jellyfin, logoSize: serviceLogoSize)
                    .font(.title3.weight(.semibold))
                    .frame(width: serviceButtonWidth, height: serviceButtonHeight)
            }
            .buttonStyle(MediaGlassButtonStyle(horizontalPadding: 0, verticalPadding: 0))

            NavigationLink(value: AppRoute.plexSetup) {
                MediaProviderLabel(providerID: .plex, logoSize: serviceLogoSize)
                    .font(.title3.weight(.semibold))
                    .frame(width: serviceButtonWidth, height: serviceButtonHeight)
            }
            .buttonStyle(MediaGlassButtonStyle(horizontalPadding: 0, verticalPadding: 0))
        }
    }

    private var serviceButtonWidth: CGFloat {
        PlatformMetadata.isPhone ? 220 : 340
    }

    private var serviceButtonHeight: CGFloat {
        PlatformMetadata.isPhone ? 72 : 120
    }

    private var serviceLogoSize: CGFloat {
        PlatformMetadata.isPhone ? 28 : 40
    }
}
