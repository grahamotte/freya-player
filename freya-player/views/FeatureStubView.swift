import SwiftUI

struct FeatureStubView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            VStack(spacing: 18) {
                Text(title)
                    .font(.title2.weight(.semibold))

                Text(message)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 720)
            .padding(28)
            .background(PanelBackground())

            Spacer()
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
        .navigationTitle(title)
    }
}
