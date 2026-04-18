import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum AppTheme {
    static let backgroundTop = Color(red: 0.08, green: 0.09, blue: 0.12)
    static let backgroundBottom = Color(red: 0.04, green: 0.05, blue: 0.07)

    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.72)
    static let inverseText = Color.black

    static let surfaceFill = Color.white.opacity(0.08)
    static let surfaceBorder = Color.white.opacity(0.12)
    static let subtleSurfaceFill = Color.white.opacity(0.05)
    static let emphasizedSurfaceFill = Color.white.opacity(0.15)

#if canImport(UIKit)
    static let uiPrimaryText = UIColor.white
    static let uiSecondaryText = UIColor.white.withAlphaComponent(0.72)
    static let uiInverseText = UIColor.black
    static let uiSurfaceFill = UIColor.white.withAlphaComponent(0.08)
    static let uiSurfaceBorder = UIColor.white.withAlphaComponent(0.12)
#endif
}

private struct AppChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(.dark)
            .foregroundStyle(AppTheme.primaryText)
    }
}

extension View {
    func appChrome() -> some View {
        modifier(AppChromeModifier())
    }
}
