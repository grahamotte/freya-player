import Combine
import Foundation
import Fuse

@MainActor
final class ServerTitleSearch: ObservableObject {
    struct Result: Identifiable {
        let item: MediaItem
        let matchedRanges: [FuseRange]
        let score: Double

        var id: String { item.id }
    }

    @Published var query = "" {
        didSet { updateResults() }
    }
    @Published private(set) var results: [Result] = []

    let server: ConnectedServer

    private static let resultLimit = 40
    private let cache: LibraryCache
    private var items: [MediaItem] = []
    private var searcher: Fuse.Search<String>?
    private var cacheSubscription: AnyCancellable?

    init(cache: LibraryCache, server: ConnectedServer) {
        self.cache = cache
        self.server = server
        rebuildIndex()
        cacheSubscription = cache.snapshotDidChange
            .throttle(for: .milliseconds(250), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.rebuildIndex()
            }
    }

    private func rebuildIndex() {
        var seenItemIDs = Set<String>()
        let nextItems = server.libraries
            .filter { !$0.isHidden }
            .flatMap { cache.searchableItems(for: $0.id) }
            .filter { seenItemIDs.insert($0.id).inserted }
        let indexIsUnchanged = items.count == nextItems.count && zip(items, nextItems).allSatisfy {
            $0.id == $1.id && $0.title == $1.title
        }
        guard !indexIsUnchanged || searcher == nil else {
            updateResults()
            return
        }

        items = nextItems
        let titles = items.map(\.title)
        let options = try? FuseOptions<String>(
            includeMatches: true,
            includeScore: true,
            threshold: 0.6,
            findAllMatches: true,
            minMatchCharLength: 1,
            ignoreLocation: true
        )
        searcher = options.flatMap { try? Fuse.Search<String>(titles, options: $0) }
        updateResults()
    }

    private func updateResults() {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, let searcher else {
            results = []
            return
        }

        results = searcher.search(trimmedQuery, limit: Self.resultLimit).compactMap { result in
            guard items.indices.contains(result.refIndex) else { return nil }
            return Result(
                item: items[result.refIndex],
                matchedRanges: result.matches?.first?.indices ?? [],
                score: result.score ?? 1
            )
        }
    }
}
