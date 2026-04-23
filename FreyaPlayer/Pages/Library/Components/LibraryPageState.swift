import Combine
import Foundation

@MainActor
final class LibraryPageState: ObservableObject {
    let model: AppModel

    @Published private(set) var library: LibraryReference
    @Published private(set) var items: [MediaItem] = []
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    @Published private(set) var filter: LibraryPageFilter
    @Published private(set) var sort: LibraryPageSort
    @Published private(set) var sortOrder: LibraryPageSortOrder
    @Published private var optimisticWatchStates: [String: Bool] = [:]

    private let store: MediaSessionStore

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
    }

    var statusItems: [MediaItem] {
        items.map(applyingOptimisticWatchStatus)
    }

    var displayedItems: [MediaItem] {
        sort.items(from: statusItems.filter { filter.matches($0) }, order: sortOrder)
    }

    var countText: String {
        let count = displayedItems.count
        let suffix = count == 1 ? library.itemTitle : "\(library.itemTitle)s"
        return "\(count) \(suffix)"
    }

    var libraryWatchStatusItem: MediaItem? {
        library.watchStatusItem(from: statusItems)
    }

    var libraryWatchStatusReloadID: String {
        library.watchStatusReloadID(from: statusItems)
    }

    func update(library: LibraryReference) {
        guard self.library != library else { return }
        self.library = library
        items = []
        optimisticWatchStates = [:]
        isLoading = true
        errorMessage = nil
        loadSavedControls()
    }

    func loadItems(showSpinner: Bool) async {
        if showSpinner {
            isLoading = true
        }
        errorMessage = nil

        do {
            let loadedItems = try await model.loadLibraryItems(for: library)
            items = loadedItems
            reconcileOptimisticWatchStates(with: loadedItems)
            isLoading = false
        } catch {
            if items.isEmpty {
                errorMessage = "Couldn't load this library."
            }
            isLoading = false
        }
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

    func setOptimisticWatchStatus(for itemID: String, isWatched: Bool) {
        optimisticWatchStates[itemID] = isWatched
    }

    func clearOptimisticWatchStatus(for itemID: String) {
        optimisticWatchStates.removeValue(forKey: itemID)
    }

    func watchTargets() async throws -> [MediaItem] {
        try await model.watchStatusTargets(in: items)
    }

    private func applyingOptimisticWatchStatus(to item: MediaItem) -> MediaItem {
        guard let isWatched = optimisticWatchStates[item.id] else { return item }
        return item.settingWatchStatus(isWatched)
    }

    private func reconcileOptimisticWatchStates(with items: [MediaItem]) {
        optimisticWatchStates = optimisticWatchStates.filter { itemID, isWatched in
            guard let actualWatchState = items.first(where: { $0.id == itemID })?.isWatched else {
                return false
            }

            return actualWatchState != isWatched
        }
    }
}
