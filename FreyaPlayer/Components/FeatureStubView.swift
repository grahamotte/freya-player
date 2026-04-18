import SwiftUI

struct FeatureStubView: View {
    let title: String
    let message: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                Button("Back to Libraries") {
                    dismiss()
                }

                Text(title)
                    .font(.title2.weight(.semibold))

                Text(message)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .frame(maxWidth: 720, alignment: .leading)
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
