import SwiftUI

struct ServerManagementSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.headline)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(PanelBackground())
        .serverManagementFocusSection()
    }
}

struct ServerManagementControlRow<Control: View>: View {
    let title: String
    let control: Control

    init(_ title: String, @ViewBuilder control: () -> Control) {
        self.title = title
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            Text(title)
                .foregroundStyle(AppTheme.secondaryText)

            Spacer(minLength: 0)

            control
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    @ViewBuilder
    func serverManagementFocusSection() -> some View {
#if os(tvOS)
        focusSection()
#else
        self
#endif
    }
}
