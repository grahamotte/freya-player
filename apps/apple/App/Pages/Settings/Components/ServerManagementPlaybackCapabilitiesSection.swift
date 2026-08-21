import AVFoundation
import SwiftUI

struct ServerManagementPlaybackCapabilitiesSection: View {
    @State private var capabilities = PlaybackCompatibility.deviceCapabilities

    var body: some View {
        ServerManagementSection("Playback Capabilities") {
            VStack(alignment: .leading, spacing: 18) {
                Text("Formats AVFoundation reports this \(PlatformMetadata.deviceName) can play. Playback options show whether Freya uses that native path or asks the server to convert the item.")
                    .foregroundStyle(AppTheme.secondaryText)

                ForEach(PlaybackCapabilityCategory.allCases) { category in
                    let categoryCapabilities = capabilities.filter { $0.category == category }
                    if !categoryCapabilities.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(category.rawValue)
                                .font(.subheadline.weight(.semibold))

                            ForEach(categoryCapabilities) { capability in
                                capabilityRow(capability)
                            }
                        }
                    }
                }

            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVPlayer.eligibleForHDRPlaybackDidChangeNotification)) { _ in
            capabilities = PlaybackCompatibility.deviceCapabilities
        }
    }

    private func capabilityRow(_ capability: PlaybackCapability) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage(for: capability.support))
                .foregroundStyle(color(for: capability.support))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(capability.name)
                        .font(.body.weight(.medium))

                    Text(capability.support.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color(for: capability.support))
                }

                Text(capability.detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func systemImage(for support: PlaybackCapabilitySupport) -> String {
        switch support {
        case .supported: "checkmark.circle.fill"
        case .conditional: "questionmark.circle.fill"
        case .unavailable: "xmark.circle.fill"
        }
    }

    private func color(for support: PlaybackCapabilitySupport) -> Color {
        switch support {
        case .supported: .green
        case .conditional: .orange
        case .unavailable: AppTheme.secondaryText
        }
    }
}
