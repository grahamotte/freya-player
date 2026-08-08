import Foundation
import SwiftUI
import UIKit

enum PlatformMetadata {
    static let isTV: Bool = UIDevice.current.userInterfaceIdiom == .tv
    static let isPhone: Bool = UIDevice.current.userInterfaceIdiom == .phone
    static let isiPad: Bool = UIDevice.current.userInterfaceIdiom == .pad
    #if targetEnvironment(macCatalyst)
    static let isMac: Bool = true
    #else
    static let isMac: Bool = false
    #endif

    static let plexPlatformName: String = {
        #if os(tvOS)
        "tvOS"
        #elseif targetEnvironment(macCatalyst)
        "MacOSX"
        #else
        "iOS"
        #endif
    }()

    static let deviceName: String = {
        #if os(tvOS)
        "Apple TV"
        #elseif targetEnvironment(macCatalyst)
        "Mac"
        #else
        PlatformMetadata.isPhone ? "iPhone" : "iPad"
        #endif
    }()

    static var libraryTileTitleSubtitleSpacing: CGFloat {
        #if os(tvOS)
        10
        #else
        2
        #endif
    }

    static var libraryTileSubtitleFont: Font {
        #if os(tvOS)
        .caption
        #else
        .footnote
        #endif
    }

    static var supportsItemTitleHoverMarquee: Bool {
        isTV || isMac
    }

    static var prefersAACPlaybackAudio: Bool {
        true
    }
}

extension PlatformMetadata {
    static func textSelectionModifier<Content: View>(_ content: Content) -> some View {
        #if os(tvOS)
        return content
        #else
        return content.textSelection(.enabled)
        #endif
    }

    static func focusSectionModifier<Content: View>(_ content: Content) -> some View {
        #if os(tvOS)
        return content.focusSection()
        #else
        return content
        #endif
    }

    static func macCommandsModifier<Content: Scene>(_ content: Content) -> some Scene {
        #if targetEnvironment(macCatalyst)
        return content.commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Freya Player") {
                    NotificationCenter.default.post(name: .navigateToAbout, object: nil)
                }
            }
            CommandGroup(replacing: .help) {
                Button("Freya Player Help") {
                    NotificationCenter.default.post(name: .navigateToAbout, object: nil)
                }
            }
        }
        #else
        return content
        #endif
    }

    static func configureFocusedImageView(_ imageView: UIImageView) {
        #if os(tvOS)
        imageView.adjustsImageWhenAncestorFocused = true
        imageView.overlayContentView.clipsToBounds = false
        #endif
    }

    static func overlayContent(for imageView: UIImageView) -> UIView {
        #if os(tvOS)
        return imageView.overlayContentView
        #else
        return imageView
        #endif
    }

    static func hoverModifier<Content: View>(_ content: Content, perform action: @escaping (Bool) -> Void) -> some View {
        #if targetEnvironment(macCatalyst)
        return content.onHover(perform: action)
        #else
        return content
        #endif
    }
}

extension View {
    func platformHover(perform action: @escaping (Bool) -> Void) -> some View {
        PlatformMetadata.hoverModifier(self, perform: action)
    }
}

struct PlatformLibraryPageContent: View {
    @ObservedObject var model: AppModel
    let library: LibraryReference
    @Binding var path: [AppRoute]

    var body: some View {
        #if os(tvOS)
        TvOSLibraryPageContent(model: model, library: library, path: $path)
        #else
        IOSLibraryPageContent(model: model, library: library)
        #endif
    }
}

struct PlatformLibrariesPageContent: View {
    @ObservedObject var model: AppModel
    let server: ConnectedServer
    @Binding var path: [AppRoute]
    let iOSLayout: AnyView

    var body: some View {
        #if os(tvOS)
        TvOSLibrariesPageContent(model: model, server: server, path: $path)
        #else
        iOSLayout
        #endif
    }
}
