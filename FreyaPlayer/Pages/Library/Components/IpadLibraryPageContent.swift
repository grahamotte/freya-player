import SwiftUI

struct IpadLibraryPageContent: View {
    @ObservedObject var model: AppModel
    let library: LibraryReference

    @State private var items: [MediaItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var filter = LibraryPageFilter.all
    @State private var sort = LibraryPageSort.title
    @State private var sortOrder = LibraryPageSortOrder.ascending

    private let store = MediaSessionStore()

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, items.isEmpty {
                VStack(spacing: 16) {
                    Text(errorMessage)
                        .foregroundStyle(AppTheme.secondaryText)

                    Button("Try Again") {
                        Task {
                            await loadItems(showSpinner: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header

                        LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                            ForEach(displayedItems) { item in
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
            loadSavedControls()
            await PollingLoop.run {
                await loadItems(showSpinner: items.isEmpty)
            }
        }
    }

    private var columns: [GridItem] {
        let minimum: CGFloat = library.artworkStyle == .poster ? 180 : 260
        return [GridItem(.adaptive(minimum: minimum, maximum: minimum + 40), spacing: 20)]
    }

    private var displayedItems: [MediaItem] {
        sort.items(from: items.filter { filter.matches($0) }, order: sortOrder)
    }

    private var tileArtworkStyle: MediaArtworkStyle {
        library.artworkStyle == .poster ? .poster : .landscape
    }

    private var countText: String {
        let count = displayedItems.count
        let suffix = count == 1 ? library.itemTitle : "\(library.itemTitle)s"
        return "\(count) \(suffix)"
    }

    private var libraryWatchStatusItem: MediaItem? {
        library.watchStatusItem(from: items)
    }

    private var libraryWatchStatusReloadID: String {
        library.watchStatusReloadID(from: items)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(library.title)
                    .font(.largeTitle.weight(.bold))

                Spacer(minLength: 0)

                Text(countText)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            HStack(alignment: .top, spacing: 12) {
                Menu {
                    ForEach(LibraryPageFilter.allCases, id: \.rawValue) { candidate in
                        Button {
                            setFilter(candidate)
                        } label: {
                            menuItemTitle(candidate.title, isSelected: candidate == filter)
                        }
                    }
                } label: {
                    Label(filter.title, systemImage: "line.3.horizontal.decrease")
                }
                .buttonStyle(MediaGlassButtonStyle())
                .fixedSize(horizontal: true, vertical: false)

                Menu {
                    Section("Field") {
                        ForEach(LibraryPageSort.allCases, id: \.rawValue) { candidate in
                            Button {
                                setSort(candidate)
                            } label: {
                                menuItemTitle(candidate.title, isSelected: candidate == sort)
                            }
                        }
                    }

                    Section("Order") {
                        ForEach(LibraryPageSortOrder.allCases, id: \.rawValue) { candidate in
                            Button {
                                setSortOrder(candidate)
                            } label: {
                                menuItemTitle(candidate.title, isSelected: candidate == sortOrder)
                            }
                        }
                    }
                } label: {
                    Label("\(sort.title) \(sortOrder.shortTitle)", systemImage: "arrow.up.arrow.down")
                }
                .buttonStyle(MediaGlassButtonStyle())
                .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 0)

                if let item = libraryWatchStatusItem {
                    MediaCollectionWatchStatusButton(
                        model: model,
                        item: item,
                        reloadID: libraryWatchStatusReloadID,
                        loadItems: {
                            try await model.watchStatusTargets(in: items)
                        },
                        onUpdateFinished: {
                            await loadItems(showSpinner: false)
                        }
                    )
                }
            }
        }
    }

    private func loadSavedControls() {
        filter = store.libraryFilter(for: library)
        sort = store.librarySort(for: library)
        sortOrder = store.librarySortOrder(for: library, sort: sort)
    }

    private func setFilter(_ filter: LibraryPageFilter) {
        self.filter = filter
        store.setLibraryFilter(filter, for: library)
    }

    private func setSort(_ sort: LibraryPageSort) {
        self.sort = sort
        if !store.hasSavedLibrarySortOrder(for: library) {
            sortOrder = sort.defaultOrder
        }
        store.setLibrarySort(sort, for: library)
    }

    private func setSortOrder(_ order: LibraryPageSortOrder) {
        sortOrder = order
        store.setLibrarySortOrder(order, for: library)
    }

    @ViewBuilder
    private func menuItemTitle(_ title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    private func loadItems(showSpinner: Bool) async {
        if showSpinner {
            isLoading = true
        }
        errorMessage = nil

        do {
            items = try await model.loadLibraryItems(for: library)
            isLoading = false
        } catch {
            if items.isEmpty {
                errorMessage = "Couldn't load this library."
                isLoading = false
            }
        }
    }
}
