import Foundation
import SwiftUI

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

struct LibraryPageFilterControl: View {
    let filter: LibraryPageFilter
    let onChange: (LibraryPageFilter) -> Void

    var body: some View {
        Menu {
            ForEach(LibraryPageFilter.allCases, id: \.rawValue) { candidate in
                Button {
                    onChange(candidate)
                } label: {
                    LibraryPageMenuItemTitle(title: candidate.title, isSelected: candidate == filter)
                }
            }
        } label: {
            Label(filter.title, systemImage: "line.3.horizontal.decrease")
        }
        .buttonStyle(MediaGlassButtonStyle())
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct LibraryPageSortControl: View {
    let sort: LibraryPageSort
    let order: LibraryPageSortOrder
    let onSortChange: (LibraryPageSort) -> Void
    let onSortOrderChange: (LibraryPageSortOrder) -> Void

    var body: some View {
        Menu {
            Section("Field") {
                ForEach(LibraryPageSort.allCases, id: \.rawValue) { candidate in
                    Button {
                        onSortChange(candidate)
                    } label: {
                        LibraryPageMenuItemTitle(title: candidate.title, isSelected: candidate == sort)
                    }
                }
            }

            Section("Order") {
                ForEach(LibraryPageSortOrder.allCases, id: \.rawValue) { candidate in
                    Button {
                        onSortOrderChange(candidate)
                    } label: {
                        LibraryPageMenuItemTitle(title: candidate.title, isSelected: candidate == order)
                    }
                }
            }
        } label: {
            Label("\(sort.title) \(order.shortTitle)", systemImage: "arrow.up.arrow.down")
        }
        .buttonStyle(MediaGlassButtonStyle())
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct LibraryPageMenuItemTitle: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}

extension MediaSessionStore {
    func libraryFilter(for library: LibraryReference) -> LibraryPageFilter {
        if let rawValue = libraryFilterRawValue(for: library),
           let filter = LibraryPageFilter(rawValue: rawValue) {
            return filter
        }

        guard
            let rawValue = defaultLibraryFilterRawValue(providerID: library.providerID, serverID: library.serverID),
            let filter = LibraryPageFilter(rawValue: rawValue)
        else {
            return .all
        }

        return filter
    }

    func setLibraryFilter(_ filter: LibraryPageFilter, for library: LibraryReference) {
        setLibraryFilterRawValue(filter.rawValue, for: library)
    }

    func defaultLibraryFilter(providerID: MediaProviderID, serverID: String) -> LibraryPageFilter {
        guard
            let rawValue = defaultLibraryFilterRawValue(providerID: providerID, serverID: serverID),
            let filter = LibraryPageFilter(rawValue: rawValue)
        else {
            return .all
        }

        return filter
    }

    func setDefaultLibraryFilter(_ filter: LibraryPageFilter, providerID: MediaProviderID, serverID: String) {
        setDefaultLibraryFilterRawValue(filter.rawValue, providerID: providerID, serverID: serverID)
    }

    func librarySort(for library: LibraryReference) -> LibraryPageSort {
        if let rawValue = librarySortRawValue(for: library),
           let sort = LibraryPageSort(rawValue: rawValue) {
            return sort
        }

        guard
            let rawValue = defaultLibrarySortRawValue(providerID: library.providerID, serverID: library.serverID),
            let sort = LibraryPageSort(rawValue: rawValue)
        else {
            return .title
        }

        return sort
    }

    func setLibrarySort(_ sort: LibraryPageSort, for library: LibraryReference) {
        setLibrarySortRawValue(sort.rawValue, for: library)
    }

    func defaultLibrarySort(providerID: MediaProviderID, serverID: String) -> LibraryPageSort {
        guard
            let rawValue = defaultLibrarySortRawValue(providerID: providerID, serverID: serverID),
            let sort = LibraryPageSort(rawValue: rawValue)
        else {
            return .title
        }

        return sort
    }

    func setDefaultLibrarySort(_ sort: LibraryPageSort, providerID: MediaProviderID, serverID: String) {
        setDefaultLibrarySortRawValue(sort.rawValue, providerID: providerID, serverID: serverID)
    }

    func librarySortOrder(for library: LibraryReference, sort: LibraryPageSort) -> LibraryPageSortOrder {
        if let rawValue = librarySortOrderRawValue(for: library),
           let order = LibraryPageSortOrder(rawValue: rawValue) {
            return order
        }

        if librarySortRawValue(for: library) != nil {
            return sort.defaultOrder
        }

        guard
            let rawValue = defaultLibrarySortOrderRawValue(providerID: library.providerID, serverID: library.serverID),
            let order = LibraryPageSortOrder(rawValue: rawValue)
        else {
            return sort.defaultOrder
        }

        return order
    }

    func setLibrarySortOrder(_ order: LibraryPageSortOrder, for library: LibraryReference) {
        setLibrarySortOrderRawValue(order.rawValue, for: library)
    }

    func defaultLibrarySortOrder(
        providerID: MediaProviderID,
        serverID: String,
        sort: LibraryPageSort
    ) -> LibraryPageSortOrder {
        guard
            let rawValue = defaultLibrarySortOrderRawValue(providerID: providerID, serverID: serverID),
            let order = LibraryPageSortOrder(rawValue: rawValue)
        else {
            return sort.defaultOrder
        }

        return order
    }

    func setDefaultLibrarySortOrder(
        _ order: LibraryPageSortOrder,
        providerID: MediaProviderID,
        serverID: String,
        sort: LibraryPageSort
    ) {
        if order == sort.defaultOrder {
            clearDefaultLibrarySortOrderRawValue(providerID: providerID, serverID: serverID)
            return
        }

        setDefaultLibrarySortOrderRawValue(order.rawValue, providerID: providerID, serverID: serverID)
    }

    func hasSavedLibrarySortOrder(for library: LibraryReference) -> Bool {
        librarySortOrderRawValue(for: library) != nil
    }

    func hasSavedDefaultLibrarySortOrder(providerID: MediaProviderID, serverID: String) -> Bool {
        defaultLibrarySortOrderRawValue(providerID: providerID, serverID: serverID) != nil
    }

    func clearLibraryFilterOverrides(for libraries: [LibraryReference]) {
        for library in libraries {
            clearLibraryFilterRawValue(for: library)
        }
    }

    func clearLibrarySortOverrides(for libraries: [LibraryReference]) {
        for library in libraries {
            clearLibrarySortRawValue(for: library)
            clearLibrarySortOrderRawValue(for: library)
        }
    }
}
