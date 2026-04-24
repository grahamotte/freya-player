import SwiftUI

extension View {
    /// Allows the user to select and copy the underlying text on platforms
    /// that support it. No-op on tvOS, where text selection is unavailable.
    @ViewBuilder
    func userSelectableText() -> some View {
        #if os(tvOS)
        self
        #else
        self.textSelection(.enabled)
        #endif
    }
}
