import Foundation

enum PlaybackCompatibility {
    static var requiresTranscodedAudio: Bool {
        #if os(tvOS)
        let processInfo = ProcessInfo.processInfo
        return requiresTranscodedAudio(
            majorVersion: processInfo.operatingSystemVersion.majorVersion,
            versionDescription: processInfo.operatingSystemVersionString
        )
        #else
        return false
        #endif
    }

    static func requiresTranscodedAudio(
        majorVersion: Int,
        versionDescription: String
    ) -> Bool {
        guard majorVersion == 27,
              let start = versionDescription.range(of: "(Build ", options: .backwards),
              let end = versionDescription[start.upperBound...].firstIndex(of: ")") else {
            return false
        }

        let buildIdentifier = versionDescription[start.upperBound..<end]
        guard let suffix = buildIdentifier.unicodeScalars.last else { return false }
        return (UnicodeScalar("a").value...UnicodeScalar("z").value).contains(suffix.value)
    }
}
