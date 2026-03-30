import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "play.tv.fill")
                .font(.system(size: 72))
                .symbolRenderingMode(.hierarchical)

            Text("Freya Player")
                .font(.title2.weight(.semibold))

            Text("A native tvOS shell for Plex and Jellyfin.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(48)
    }
}
