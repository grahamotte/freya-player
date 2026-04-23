import SwiftUI

struct IpadLibraryPageContent: View {
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
            if state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = state.errorMessage, state.items.isEmpty {
                VStack(spacing: 16) {
                    Text(errorMessage)
                        .foregroundStyle(AppTheme.secondaryText)

                    Button("Try Again") {
                        Task {
                            await state.loadItems(showSpinner: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header

                        LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                            ForEach(state.displayedItems) { item in
                                NavigationLink(value: item.route) {
                                    LibraryItemCard(item: item, artworkStyle: tileArtworkStyle)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(32)
                }
            }
        }
        .background(AppBackground())
        .task(id: library.id) {
            state.update(library: library)
            await PollingLoop.run {
                await state.loadItems(showSpinner: state.items.isEmpty)
            }
        }
        .onReceive(defaultsDidChange) { _ in
            state.loadSavedControls()
        }
    }

    private var columns: [GridItem] {
        let minimum: CGFloat = state.library.artworkStyle == .poster ? 180 : 260
        return [GridItem(.adaptive(minimum: minimum, maximum: minimum + 40), spacing: 20)]
    }

    private var tileArtworkStyle: MediaArtworkStyle {
        state.library.artworkStyle == .poster ? .poster : .landscape
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(state.library.title)
                    .font(.largeTitle.weight(.bold))

                Spacer(minLength: 0)

                Text(state.countText)
                    .foregroundStyle(AppTheme.secondaryText)
            }

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
                    MediaCollectionWatchStatusButton(
                        model: model,
                        item: item,
                        reloadID: state.libraryWatchStatusReloadID,
                        loadItems: {
                            try await state.watchTargets()
                        },
                        onUpdateFinished: {
                            await state.loadItems(showSpinner: false)
                        }
                    )
                }
            }
        }
    }
}
