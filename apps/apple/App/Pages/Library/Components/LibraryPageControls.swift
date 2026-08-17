import SwiftUI

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
