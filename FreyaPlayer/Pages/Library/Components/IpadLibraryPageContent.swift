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
        guard !items.isEmpty else { return nil }

        let progress = items.reduce(0.0) { partial, item in
            partial + (item.isWatched ? 1 : min(max(item.progress ?? 0, 0), 1))
        } / Double(items.count)
        let isWatched = items.allSatisfy(\.isWatched)

        return MediaItem(
            providerID: library.providerID,
            serverID: library.serverID,
            id: "library:\(library.id)",
            title: library.title,
            kind: library.defaultItemKind,
            synopsis: "",
            addedAt: nil,
            year: nil,
            durationMilliseconds: nil,
            contentRating: nil,
            isWatched: isWatched,
            progress: isWatched ? 1 : (progress > 0 ? progress : nil),
            resumeOffsetMilliseconds: nil,
            artwork: .init(posterURL: nil, landscapeURL: nil, backdropURL: nil)
        )
    }

    private var libraryWatchStatusReloadID: String {
        items.map {
            "\($0.id):\($0.isWatched):\($0.progress ?? 0):\($0.resumeOffsetMilliseconds ?? 0)"
        }.joined(separator: ",")
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
                        Button(candidate.title) {
                            setFilter(candidate)
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
                            Button(candidate.title) {
                                setSort(candidate)
                            }
                        }
                    }

                    Section("Order") {
                        ForEach(LibraryPageSortOrder.allCases, id: \.rawValue) { candidate in
                            Button(candidate.title) {
                                setSortOrder(candidate)
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
                            try await loadWatchTargets(in: items)
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
        if let rawValue = store.libraryFilterRawValue(for: library),
           let savedFilter = LibraryPageFilter(rawValue: rawValue) {
            filter = savedFilter
        }

        if let rawValue = store.librarySortRawValue(for: library),
           let savedSort = LibraryPageSort(rawValue: rawValue) {
            sort = savedSort
        }

        if let rawValue = store.librarySortOrderRawValue(for: library),
           let savedSortOrder = LibraryPageSortOrder(rawValue: rawValue) {
            sortOrder = savedSortOrder
        } else {
            sortOrder = sort.defaultOrder
        }
    }

    private func setFilter(_ filter: LibraryPageFilter) {
        self.filter = filter
        store.setLibraryFilterRawValue(filter.rawValue, for: library)
    }

    private func setSort(_ sort: LibraryPageSort) {
        self.sort = sort
        if store.librarySortOrderRawValue(for: library) == nil {
            sortOrder = sort.defaultOrder
        }
        store.setLibrarySortRawValue(sort.rawValue, for: library)
    }

    private func setSortOrder(_ order: LibraryPageSortOrder) {
        sortOrder = order
        store.setLibrarySortOrderRawValue(order.rawValue, for: library)
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

    private func loadWatchTargets(in items: [MediaItem]) async throws -> [MediaItem] {
        var targets: [MediaItem] = []

        for item in items {
            if item.playbackID != nil {
                targets.append(item)
            } else {
                let children = try await model.loadChildren(for: item)
                targets += try await loadWatchTargets(in: children)
            }
        }

        return targets
    }
}
