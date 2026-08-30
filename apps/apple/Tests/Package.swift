// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FreyaPlayer",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(
            url: "https://github.com/krisk/fuse-swift.git",
            exact: "2.0.0-rc.1"
        ),
    ],
    targets: [
        .target(
            name: "FreyaPlayerCore",
            dependencies: [
                .product(name: "Fuse", package: "fuse-swift"),
            ],
            path: "App",
            exclude: [
                "AppModel.swift",
                "AppRoute.swift",
                "AppView.swift",
                "Assets.xcassets",
                "Components",
                "Config",
                "Connectors/Jellyfin/JellyfinClient.swift",
                "Connectors/Jellyfin/JellyfinConnector.swift",
                "Connectors/Jellyfin/JellyfinModels.swift",
                "Connectors/Jellyfin/JellyfinSessionStore.swift",
                "Connectors/MediaConnector.swift",
                "Connectors/Plex/PlexClient.swift",
                "Connectors/Plex/PlexConnector.swift",
                "Connectors/Plex/PlexModels.swift",
                "Connectors/Plex/PlexSessionStore.swift",
                "FreyaPlayerApp.swift",
                "Libraries/KeychainStore.swift",
                "Libraries/MediaViewData+MediaItem.swift",
                "Libraries/PlatformMetadata.swift",
                "Libraries/PlaybackAudioSession.swift",
                "Libraries/PollingLoop.swift",
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
