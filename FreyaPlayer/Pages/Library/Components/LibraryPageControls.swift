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
