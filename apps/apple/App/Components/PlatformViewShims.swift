import SwiftUI

extension Notification.Name {
    static let navigateToAbout = Notification.Name("com.grahamotte.freyaplayer.navigateToAbout")
}

extension View {
    func userSelectableText() -> some View {
        PlatformMetadata.textSelectionModifier(self)
    }

    func tvOSFocusSection() -> some View {
        PlatformMetadata.focusSectionModifier(self)
    }
}

extension Scene {
    func macOSCommands() -> some Scene {
        PlatformMetadata.macCommandsModifier(self)
    }
}
