import SwiftUI

struct TVChildListSection: View {
    @ObservedObject var model: AppModel
    let item: MediaItem
    let title: String
    let emptyMessage: String
    let destination: (MediaItem) -> AppRoute
    let rowStyle: RowStyle

    @State private var children: [MediaItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.title3.weight(.semibold))

            if isLoading {
                ProgressView()
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
            } else if children.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(children.enumerated()), id: \.element.id) { position, child in
                        NavigationLink(value: destination(child)) {
                            HStack(spacing: 18) {
                                Text(title(for: child, position: position))
                                    .font(.headline)
                                    .lineLimit(1)

                                Spacer(minLength: 0)

                                if showsWatchedBadge(for: child) {
                                    TVWatchedBadge()
                                }

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 18))
                        .controlSize(.large)
                    }
                }
            }
        }
        .task(id: item.id) {
            await PollingLoop.run {
                await loadChildren()
            }
        }
    }

    private func loadChildren() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            children = try await model.loadChildren(for: item)
            errorMessage = nil
        } catch {
            if children.isEmpty {
                errorMessage = "Couldn't load this list right now."
            }
        }
    }

    private func title(for child: MediaItem, position: Int) -> String {
        switch rowStyle {
        case .standard:
            return child.title
        case .numbered:
            return "\(position + 1). \(child.title)"
        }
    }

    private func showsWatchedBadge(for child: MediaItem) -> Bool {
        child.isWatched && (child.kind == .season || child.kind == .episode)
    }
}

extension TVChildListSection {
    enum RowStyle {
        case standard
        case numbered
    }
}

private struct TVWatchedBadge: View {
    var body: some View {
        Circle()
            .fill(MediaWatchStatusDisplay.color)
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
            }
    }
}
