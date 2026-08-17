import SwiftUI

struct IOSLibraryPageContent: View {
    @ObservedObject var model: AppModel
    let library: LibraryReference

    @StateObject private var state: LibraryPageState
    private let defaultsDidChange = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)

    init(model: AppModel, library: LibraryReference) {
        self.model = model
        self.library = library
        _state = StateObject(wrappedValue: LibraryPageState(model: model, library: library))
    }

    var body: some View {
        Group {
            if state.isLoadingFirstPage {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: contentSpacing) {
                        header

                        LazyVGrid(columns: columns, alignment: .leading, spacing: gridSpacing) {
                            ForEach(state.displayedItems) { item in
                                itemLink(item)
                            }
                        }
                    }
                    .padding(contentPadding)
                }
            }
        }
        .background(AppBackground())
        .task(id: library.id) {
            state.update(library: library)
        }
        .onReceive(defaultsDidChange) { _ in
            state.loadSavedControls()
        }
    }

    private var contentPadding: CGFloat { PlatformMetadata.isPhone ? 16 : 32 }
    private var contentSpacing: CGFloat { PlatformMetadata.isPhone ? 20 : 28 }
    private var gridSpacing: CGFloat { PlatformMetadata.isPhone ? 16 : 24 }

    private var columns: [GridItem] {
        if PlatformMetadata.isPhone {
            return Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: 2)
        }
        if PlatformMetadata.isMac {
            let minimum: CGFloat = state.library.artworkStyle == .poster ? 180 : 260
            return [GridItem(.adaptive(minimum: minimum, maximum: minimum + 40), spacing: 16)]
        }
        let count = state.library.artworkStyle == .poster ? 4 : 3
        return Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: count)
    }

    private var tileArtworkStyle: MediaArtworkStyle {
        state.library.artworkStyle == .poster ? .poster : .landscape
    }

    private var showsTileAddedAt: Bool {
        state.sort == .addedAt
    }

    private func itemLink(_ item: MediaItem) -> some View {
        NavigationLink(value: item.route) {
            LibraryItemCard(
                item: item,
                artworkStyle: tileArtworkStyle,
                showsAddedAt: showsTileAddedAt
            )
        }
        .buttonStyle(.plain)
        .mediaItemQuickActions(model: model, item: item)
    }

    private var header: some View {
        Group {
            if PlatformMetadata.isPhone {
                phoneHeader
            } else {
                padOrMacHeader
            }
        }
    }

    private var phoneHeader: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            Text(state.library.title)
                .font(.largeTitle.weight(.bold))
                .lineLimit(1)

            HStack(alignment: .top, spacing: 12) {
                LibraryPageFilterControl(filter: state.filter, onChange: state.setFilter)

                LibraryPageSortControl(
                    sort: state.sort,
                    order: state.sortOrder,
                    onSortChange: state.setSort,
                    onSortOrderChange: state.setSortOrder
                )

                Spacer(minLength: 0)
            }

            if let item = state.libraryWatchStatusItem {
                HStack(spacing: 12) {
                    MediaPlayAllButton(model: model, items: state.displayedPlayableItems)
                    MediaCollectionWatchStatusButton(
                        model: model,
                        libraryItem: item,
                        libraryID: state.library.id
                    )
                }
            }

            Text(state.countText)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var padOrMacHeader: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text(state.library.title)
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(state.countText)
                    .foregroundStyle(AppTheme.secondaryText)
                    .layoutPriority(1)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    LibraryPageFilterControl(filter: state.filter, onChange: state.setFilter)

                    LibraryPageSortControl(
                        sort: state.sort,
                        order: state.sortOrder,
                        onSortChange: state.setSort,
                        onSortOrderChange: state.setSortOrder
                    )

                    Spacer(minLength: 0)

                    if let item = state.libraryWatchStatusItem {
                        MediaPlayAllButton(model: model, items: state.displayedPlayableItems)

                        MediaCollectionWatchStatusButton(
                            model: model,
                            libraryItem: item,
                            libraryID: state.library.id
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    LibraryPageFilterControl(filter: state.filter, onChange: state.setFilter)

                    LibraryPageSortControl(
                        sort: state.sort,
                        order: state.sortOrder,
                        onSortChange: state.setSort,
                        onSortOrderChange: state.setSortOrder
                    )

                    if let item = state.libraryWatchStatusItem {
                        MediaPlayAllButton(model: model, items: state.displayedPlayableItems)

                        MediaCollectionWatchStatusButton(
                            model: model,
                            libraryItem: item,
                            libraryID: state.library.id
                        )
                    }
                }
            }
        }
    }
}
