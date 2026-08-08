import SwiftUI

struct ServerManagementSortSection: View {
    let defaultFilter: LibraryPageFilter
    let defaultSort: LibraryPageSort
    let defaultSortOrder: LibraryPageSortOrder
    let onFilterChange: (LibraryPageFilter) -> Void
    let onSortChange: (LibraryPageSort) -> Void
    let onSortOrderChange: (LibraryPageSortOrder) -> Void

    var body: some View {
        ServerManagementSection("Sort") {
            VStack(alignment: .leading, spacing: 18) {
                ServerManagementControlRow("Default Library Filter") {
                    LibraryPageFilterControl(filter: defaultFilter, onChange: onFilterChange)
                }

                ServerManagementControlRow("Default Library Sort") {
                    LibraryPageSortControl(
                        sort: defaultSort,
                        order: defaultSortOrder,
                        onSortChange: onSortChange,
                        onSortOrderChange: onSortOrderChange
                    )
                }
            }
        }
    }
}
