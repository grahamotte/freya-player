import Combine
import Foundation

@MainActor
final class LibraryPageState: ObservableObject {
    let model: AppModel

    @Published private(set) var library: LibraryReference
    @Published private(set) var filter: LibraryPageFilter
    @Published private(set) var sort: LibraryPageSort
    @Published private(set) var sortOrder: LibraryPageSortOrder

    private let store: MediaSessionStore
    private var cacheSubscription: AnyCancellable?
    private var modelSubscription: AnyCancellable?
    private var warmTask: Task<Void, Never>?

    init(model: AppModel, library: LibraryReference) {
        let store = MediaSessionStore()
        let filter = store.libraryFilter(for: library)
        let sort = store.librarySort(for: library)

        self.model = model
        self.library = library
        self.store = store
        self.filter = filter
        self.sort = sort
        self.sortOrder = store.librarySortOrder(for: library, sort: sort)

        cacheSubscription = model.libraryCache.snapshotDidChange
            .throttle(for: .milliseconds(250), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Mirror tracker changes so the empty-state spinner clears as soon as
        // the first refresh finishes. Throttled so warm-loop churn doesn't
        // thrash the UI.
        modelSubscription = model.refreshTracker.objectWillChange
            .throttle(for: .milliseconds(250), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    deinit {
        warmTask?.cancel()
    }

    var items: [MediaItem] {
        model.libraryCache.libraryItems(for: library.id)
    }

    var displayedItems: [MediaItem] {
        sort.items(from: items.filter { filter.matches($0) }, order: sortOrder)
    }

    var displayedPlayableItems: [MediaItem] {
        displayedItems.flatMap { model.libraryCache.leaves(under: $0.id) }.filter { filter.matches($0) }
    }

    var countText: String {
        let count = displayedItems.count
        let suffix = count == 1 ? library.itemTitle : "\(library.itemTitle)s"
        return "\(count) \(suffix)"
    }

    /// True only when the cache is empty AND the first refresh hasn't returned
    /// yet. Once items land, the spinner goes away regardless of subsequent
    /// background refreshes.
    var isLoadingFirstPage: Bool {
        items.isEmpty && model.refreshTracker.isRefreshing(.library(library.id))
    }

    var libraryWatchStatusItem: MediaItem? {
        guard let synthetic = library.watchStatusItem(from: items) else { return nil }
        return model.libraryCache.derivedLibraryItem(synthetic, libraryID: library.id)
    }

    var libraryWatchStatusReloadID: String {
        library.watchStatusReloadID(from: items)
    }

    func update(library: LibraryReference) {
        guard self.library != library else { return }
        warmTask?.cancel()
        warmTask = nil
        self.library = library
        loadSavedControls()
    }

    /// Refresh top-level items on every poll and warm series once per visit.
    func refresh() {
        model.refreshLibrary(library)
        guard warmTask == nil else { return }
        warmTask = model.warmLibraryChildren(library)
    }

    func loadSavedControls() {
        let nextFilter = store.libraryFilter(for: library)
        let nextSort = store.librarySort(for: library)
        let nextSortOrder = store.librarySortOrder(for: library, sort: nextSort)

        guard filter != nextFilter || sort != nextSort || sortOrder != nextSortOrder else { return }

        filter = nextFilter
        sort = nextSort
        sortOrder = nextSortOrder
    }

    func setFilter(_ filter: LibraryPageFilter) {
        guard self.filter != filter else { return }
        self.filter = filter
        store.setLibraryFilter(filter, for: library)
    }

    func setSort(_ sort: LibraryPageSort) {
        guard self.sort != sort else { return }
        self.sort = sort
        if !store.hasSavedLibrarySortOrder(for: library) {
            sortOrder = sort.defaultOrder
        }
        store.setLibrarySort(sort, for: library)
    }

    func setSortOrder(_ order: LibraryPageSortOrder) {
        guard sortOrder != order else { return }
        sortOrder = order
        store.setLibrarySortOrder(order, for: library)
    }
}
