import Foundation

enum LibraryPageFilter: Int, CaseIterable {
    case all
    case unwatched

    var title: String {
        switch self {
        case .all:
            return "All"
        case .unwatched:
            return "Unwatched"
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
            return "No unwatched \(plural)."
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
                return order.compare(lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending)
            case .addedAt:
                if let lhsAddedAt = lhs.addedAt, let rhsAddedAt = rhs.addedAt, lhsAddedAt != rhsAddedAt {
                    return order.compare(lhsAddedAt < rhsAddedAt)
                }
                if lhs.addedAt != nil || rhs.addedAt != nil {
                    return order.compare((lhs.addedAt ?? .min) < (rhs.addedAt ?? .min))
                }
                return order.compare(lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending)
            case .duration:
                if let lhsDuration = lhs.durationMilliseconds, let rhsDuration = rhs.durationMilliseconds, lhsDuration != rhsDuration {
                    return order.compare(lhsDuration < rhsDuration)
                }
                if lhs.durationMilliseconds != nil || rhs.durationMilliseconds != nil {
                    return order.compare((lhs.durationMilliseconds ?? .min) < (rhs.durationMilliseconds ?? .min))
                }
                return order.compare(lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending)
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
}

extension MediaSessionStore {
    func libraryFilter(for library: LibraryReference) -> LibraryPageFilter {
        guard
            let rawValue = libraryFilterRawValue(for: library),
            let filter = LibraryPageFilter(rawValue: rawValue)
        else {
            return .all
        }

        return filter
    }

    func setLibraryFilter(_ filter: LibraryPageFilter, for library: LibraryReference) {
        setLibraryFilterRawValue(filter.rawValue, for: library)
    }

    func librarySort(for library: LibraryReference) -> LibraryPageSort {
        guard
            let rawValue = librarySortRawValue(for: library),
            let sort = LibraryPageSort(rawValue: rawValue)
        else {
            return .title
        }

        return sort
    }

    func setLibrarySort(_ sort: LibraryPageSort, for library: LibraryReference) {
        setLibrarySortRawValue(sort.rawValue, for: library)
    }

    func librarySortOrder(for library: LibraryReference, sort: LibraryPageSort) -> LibraryPageSortOrder {
        guard
            let rawValue = librarySortOrderRawValue(for: library),
            let order = LibraryPageSortOrder(rawValue: rawValue)
        else {
            return sort.defaultOrder
        }

        return order
    }

    func setLibrarySortOrder(_ order: LibraryPageSortOrder, for library: LibraryReference) {
        setLibrarySortOrderRawValue(order.rawValue, for: library)
    }

    func hasSavedLibrarySortOrder(for library: LibraryReference) -> Bool {
        librarySortOrderRawValue(for: library) != nil
    }
}
