import Foundation

enum PlatformMetadata {
    static let plexPlatformName: String = {
        #if os(tvOS)
        "tvOS"
        #else
        "iOS"
        #endif
    }()

    static let deviceName: String = {
        #if os(tvOS)
        "Apple TV"
        #else
        "iPad"
        #endif
    }()
}
