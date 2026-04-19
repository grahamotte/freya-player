import SwiftUI

struct ProviderPickerView: View {
    var body: some View {
        VStack {
            HStack(spacing: 72) {
                NavigationLink(value: AppRoute.jellyfinSetup) {
                    serviceButton(title: "Jellyfin", systemImage: "square.stack.3d.up.fill")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 28))
                .controlSize(.large)

                NavigationLink(value: AppRoute.plexSetup) {
                    serviceButton(title: "Plex", systemImage: "play.rectangle.fill")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 28))
                .controlSize(.large)
            }
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
        .navigationTitle("Freya Player")
    }

    private func serviceButton(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.title3.weight(.semibold))
            .frame(width: 280, height: 140)
    }
}
