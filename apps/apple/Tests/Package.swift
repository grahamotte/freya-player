// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FreyaPlayer",
    platforms: [.macOS(.v15)],
    targets: [
        .target(
            name: "FreyaPlayerCore",
            path: "App",
            exclude: [
                "AppModel.swift",
                "AppRoute.swift",
                "AppView.swift",
                "Assets.xcassets",
                "Components",
                "Config",
                "Connectors/Jellyfin",
                "Connectors/MediaConnector.swift",
                "Connectors/Plex/PlexClient.swift",
                "Connectors/Plex/PlexConnector.swift",
                "Connectors/Plex/PlexModels.swift",
                "Connectors/Plex/PlexSessionStore.swift",
                "FreyaPlayerApp.swift",
                "Libraries/KeychainStore.swift",
                "Libraries/LibraryCache.swift",
                "Libraries/MediaViewData+MediaItem.swift",
                "Libraries/PlatformMetadata.swift",
                "Libraries/PlaybackAudioSession.swift",
                "Libraries/PollingLoop.swift",
                "Libraries/RefreshTracker.swift",
                "Pages",
            ],
            swiftSettings: [.swiftLanguageMode(.v5)],
        ),
        .testTarget(
            name: "FreyaPlayerCoreTests",
            dependencies: ["FreyaPlayerCore"],
            path: "Tests",
            exclude: ["Package.swift"],
        ),
    ]
)
