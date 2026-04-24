import SwiftUI

struct AboutPage: View {
    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            VStack(alignment: .leading, spacing: 24) {
                Label("About Freya Player", systemImage: "info.circle")
                    .font(.title3.weight(.semibold))

                Text("A small, native player for Jellyfin and Plex, built to feel like it came with the device.")
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                section(
                    title: "Free Forever",
                    body: "Freya Player is free. No subscriptions, no upsell, no plus premium max whatever. Oh also, no ads."
                )

                section(
                    title: "Private by Default",
                    body: "Your data lives only on this device, so the app can talk to your server. There's no analytics or telemetry, not even a crash reporter."
                )

                section(
                    title: "Open Source",
                    body: "Read it, fork it, send a pull request."
                )

                VStack(alignment: .leading, spacing: 6) {
                    sectionTitle("Bugs?")
                    Text("Open an issue!")
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("https://codeberg.org/grahamotte/freya-player")
                        .font(.body.monospaced())
                        .foregroundStyle(AppTheme.primaryText)
                        .userSelectableText()
                }
            }
            .frame(maxWidth: PlatformMetadata.isTV ? 1200 : 720, alignment: .leading)
            .padding(28)
            .background(PanelBackground())

            Spacer()
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
        .navigationTitle("About")
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle(title)
            Text(body)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(AppTheme.primaryText)
    }
}
