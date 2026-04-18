import SwiftUI

struct ItemChildListSection: View {
    @ObservedObject var model: AppModel
    let item: MediaItem
    let title: String
    let emptyMessage: String
    let destination: (MediaItem) -> AppRoute
    let rowStyle: RowStyle
    let autoFocusNextUnwatched: Bool

    @State private var children: [MediaItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedChildID: String?

    init(
        model: AppModel,
        item: MediaItem,
        title: String,
        emptyMessage: String,
        destination: @escaping (MediaItem) -> AppRoute,
        rowStyle: RowStyle,
        autoFocusNextUnwatched: Bool = false
    ) {
        self.model = model
        self.item = item
        self.title = title
        self.emptyMessage = emptyMessage
        self.destination = destination
        self.rowStyle = rowStyle
        self.autoFocusNextUnwatched = autoFocusNextUnwatched
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.title3.weight(.semibold))

            if isLoading {
                ProgressView()
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(AppTheme.secondaryText)
            } else if children.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(AppTheme.secondaryText)
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
                                    ItemWatchedBadge()
                                }

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 18))
                        .controlSize(.large)
                        .focused($focusedChildID, equals: child.id)
                    }
                }
            }
        }
        .task(id: item.id) {
            focusedChildID = nil
            await loadChildren()
        }
    }

    private func loadChildren() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedChildren = try await model.loadChildren(for: item)
            children = loadedChildren
            errorMessage = nil
            if autoFocusNextUnwatched, let focusedChildID = nextUnwatchedChildID(in: loadedChildren) {
                await Task.yield()
                self.focusedChildID = focusedChildID
            }
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

    private func nextUnwatchedChildID(in children: [MediaItem]) -> String? {
        children.first(where: { !$0.isWatched })?.id
    }
}

extension ItemChildListSection {
    enum RowStyle {
        case standard
        case numbered
    }
}

private struct ItemWatchedBadge: View {
    var body: some View {
        Circle()
            .fill(MediaWatchStatusDisplay.color)
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.inverseText)
            }
    }
}
