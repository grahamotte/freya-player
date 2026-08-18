import SwiftUI

struct ItemChildListSection: View {
    @Environment(\.mediaViewScrollTo) private var scrollTo
    @ObservedObject var model: AppModel
    @ObservedObject var cache: LibraryCache
    @ObservedObject var refreshTracker: RefreshTracker
    let item: MediaItem
    let title: String
    let emptyMessage: String
    let destination: (MediaItem) -> AppRoute
    let rowStyle: RowStyle
    let autoFocusNextUnwatched: Bool

    @State private var didApplyAutoFocus = false
    @State private var hoveredChildID: String?
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
        self.cache = model.libraryCache
        self.refreshTracker = model.refreshTracker
        self.item = item
        self.title = title
        self.emptyMessage = emptyMessage
        self.destination = destination
        self.rowStyle = rowStyle
        self.autoFocusNextUnwatched = autoFocusNextUnwatched
    }

    private var children: [MediaItem] {
        cache.children(of: item.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.title3.weight(.semibold))

            if children.isEmpty {
                if refreshTracker.isRefreshing(.children(item.id)) {
                    ProgressView()
                } else {
                    Text(emptyMessage)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(children.enumerated()), id: \.element.id) { position, child in
                        let usesFocusedForeground = PlatformMetadata.isTV && focusedChildID == child.id

                        NavigationLink(value: destination(child)) {
                            HStack(spacing: 18) {
                                MarqueeText(
                                    text: title(for: child, position: position),
                                    font: .headline,
                                    isActive: PlatformMetadata.supportsItemTitleHoverMarquee
                                        && (focusedChildID == child.id || hoveredChildID == child.id)
                                )

                                Spacer(minLength: 0)

                                if showsProgress(for: child) {
                                    WatchProgressCircle(progress: child.progress, isWatched: child.isWatched)
                                }

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(
                                        usesFocusedForeground ? AppTheme.inverseText.opacity(0.72) : AppTheme.secondaryText
                                    )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(usesFocusedForeground ? AppTheme.inverseText : AppTheme.primaryText)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 18))
                        .controlSize(.large)
                        .id(child.id)
                        .focused($focusedChildID, equals: child.id)
                        .platformHover { hoveredChildID = $0 ? child.id : nil }
                    }
                }
            }
        }
        .task(id: item.id) {
            focusedChildID = nil
            didApplyAutoFocus = false
            applyAutoFocusIfNeeded()
            model.refreshChildren(of: item)
        }
        .onChange(of: children.count) { _, _ in
            applyAutoFocusIfNeeded()
        }
    }

    private func applyAutoFocusIfNeeded() {
        guard autoFocusNextUnwatched, !didApplyAutoFocus else { return }
        guard let nextID = nextUnwatchedChildID(in: children) else { return }

        didApplyAutoFocus = true
        Task {
            await Task.yield()
            focusedChildID = nextID
            if !PlatformMetadata.isTV {
                scrollTo(nextID)
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

    private func showsProgress(for child: MediaItem) -> Bool {
        child.kind == .season || child.kind == .episode
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
