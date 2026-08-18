import Foundation

enum LibraryPageFilter: Int, CaseIterable {
    case all
    case unwatched

    var title: String {
        switch self {
        case .all:
            return "All"
        case .unwatched:
            return "Unseen"
        }
    }

    func matches(_ item: MediaItem) -> Bool {
        switch self {
        case .all:
            return true
        case .unwatched:
            return !item.isWatched
        }
    }

    func emptyStateText(for itemName: String) -> String {
        let plural = "\(itemName)s"

        switch self {
        case .all:
            return "No \(plural)."
        case .unwatched:
            return "No unseen \(plural)."
        }
    }
}

enum LibraryPageSort: Int, CaseIterable {
    case title
    case addedAt
    case duration

    var title: String {
        switch self {
        case .title:
            return "Title"
        case .addedAt:
            return "Added At"
        case .duration:
            return "Duration"
        }
    }

    var defaultOrder: LibraryPageSortOrder {
        switch self {
        case .title:
            return .ascending
        case .addedAt, .duration:
            return .descending
        }
    }

    func items(from items: [MediaItem], order: LibraryPageSortOrder) -> [MediaItem] {
        items.sorted { lhs, rhs in
            switch self {
            case .title:
                return order.compare(lhs.title.localizedStandardCompare(rhs.title))
            case .addedAt:
                if let lhsAddedAt = lhs.addedAt, let rhsAddedAt = rhs.addedAt, lhsAddedAt != rhsAddedAt {
                    return order.compare(lhsAddedAt < rhsAddedAt)
                }
                if lhs.addedAt != rhs.addedAt {
                    return order.compare((lhs.addedAt ?? .min) < (rhs.addedAt ?? .min))
                }
                return order.compare(lhs.title.localizedStandardCompare(rhs.title))
            case .duration:
                if let lhsDuration = lhs.durationMilliseconds, let rhsDuration = rhs.durationMilliseconds, lhsDuration != rhsDuration {
                    return order.compare(lhsDuration < rhsDuration)
                }
                if lhs.durationMilliseconds != rhs.durationMilliseconds {
                    return order.compare((lhs.durationMilliseconds ?? .min) < (rhs.durationMilliseconds ?? .min))
                }
                return order.compare(lhs.title.localizedStandardCompare(rhs.title))
            }
        }
    }
}

enum LibraryPageSortOrder: Int, CaseIterable {
    case ascending
    case descending

    var title: String {
        switch self {
        case .ascending:
            return "Ascending"
        case .descending:
            return "Descending"
        }
    }

    var shortTitle: String {
        switch self {
        case .ascending:
            return "Asc"
        case .descending:
            return "Desc"
        }
    }

    func compare(_ isAscending: Bool) -> Bool {
        switch self {
        case .ascending:
            return isAscending
        case .descending:
            return !isAscending
        }
    }

    func compare(_ result: ComparisonResult) -> Bool {
        switch self {
        case .ascending:
            return result == .orderedAscending
        case .descending:
            return result == .orderedDescending
        }
    }
}

extension MediaSessionStore {
    func libraryFilter(for library: LibraryReference) -> LibraryPageFilter {
        if let rawValue = libraryFilterRawValue(for: library),
           let filter = LibraryPageFilter(rawValue: rawValue) {
            return filter
        }

        return .unwatched
    }

    func setLibraryFilter(_ filter: LibraryPageFilter, for library: LibraryReference) {
        setLibraryFilterRawValue(filter.rawValue, for: library)
    }

    func librarySort(for library: LibraryReference) -> LibraryPageSort {
        if let rawValue = librarySortRawValue(for: library),
           let sort = LibraryPageSort(rawValue: rawValue) {
            return sort
        }

        return .addedAt
    }

    func setLibrarySort(_ sort: LibraryPageSort, for library: LibraryReference) {
        setLibrarySortRawValue(sort.rawValue, for: library)
    }

    func librarySortOrder(for library: LibraryReference, sort: LibraryPageSort) -> LibraryPageSortOrder {
        if let rawValue = librarySortOrderRawValue(for: library),
           let order = LibraryPageSortOrder(rawValue: rawValue) {
            return order
        }

        return sort.defaultOrder
    }

    func setLibrarySortOrder(_ order: LibraryPageSortOrder, for library: LibraryReference) {
        setLibrarySortOrderRawValue(order.rawValue, for: library)
    }

    func hasSavedLibrarySortOrder(for library: LibraryReference) -> Bool {
        librarySortOrderRawValue(for: library) != nil
    }
}
