import SwiftUI

struct ServerManagementPanel: View {
    @ObservedObject var model: AppModel
    @Binding var path: [AppRoute]

    @State private var defaultFilter = LibraryPageFilter.all
    @State private var defaultSort = LibraryPageSort.title
    @State private var defaultSortOrder = LibraryPageSortOrder.ascending
    @State private var isShowingDeactivateAlert = false

    private let store = MediaSessionStore()

    var body: some View {
        ScrollView {
            if let server = model.connectedServer {
                VStack(alignment: .leading, spacing: 24) {
                    ServerManagementServerSection(server: server) {
                        isShowingDeactivateAlert = true
                    }

                    ServerManagementSortSection(
                        defaultFilter: defaultFilter,
                        defaultSort: defaultSort,
                        defaultSortOrder: defaultSortOrder,
                        onFilterChange: { filter in
                            setDefaultFilter(filter, for: server)
                        },
                        onSortChange: { sort in
                            setDefaultSort(sort, for: server)
                        },
                        onSortOrderChange: { order in
                            setDefaultSortOrder(order, for: server)
                        }
                    )

                    ServerManagementLibrariesSection(
                        libraries: server.libraries,
                        onToggleVisibility: { index, isHidden in
                            model.setLibraryHidden(isHidden, at: index)
                        },
                        onMoveLibrary: { index, offset in
                            model.moveLibrary(at: index, by: offset)
                        }
                    )
                }
                .frame(maxWidth: 860, alignment: .leading)
                .padding(32)
                .padding(48)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
        .task(id: model.connectedServer?.id) {
            loadDefaults()
        }
        .alert("Deactivate Server?", isPresented: $isShowingDeactivateAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Deactivate", role: .destructive) {
                model.disconnectCurrentServer()
                path.removeAll()
            }
        } message: {
            Text("This removes the current server from Freya Player.")
        }
    }

    private func loadDefaults() {
        guard let server = model.connectedServer else { return }
        defaultFilter = store.defaultLibraryFilter(providerID: server.providerID, serverID: server.serverID)
        defaultSort = store.defaultLibrarySort(providerID: server.providerID, serverID: server.serverID)
        defaultSortOrder = store.defaultLibrarySortOrder(
            providerID: server.providerID,
            serverID: server.serverID,
            sort: defaultSort
        )
    }

    private func setDefaultFilter(_ filter: LibraryPageFilter, for server: ConnectedServer) {
        defaultFilter = filter
        store.setDefaultLibraryFilter(filter, providerID: server.providerID, serverID: server.serverID)
        store.clearLibraryFilterOverrides(for: server.libraries.map(\.reference))
    }

    private func setDefaultSort(_ sort: LibraryPageSort, for server: ConnectedServer) {
        defaultSort = sort

        if !store.hasSavedDefaultLibrarySortOrder(providerID: server.providerID, serverID: server.serverID) {
            defaultSortOrder = sort.defaultOrder
        }

        store.setDefaultLibrarySort(sort, providerID: server.providerID, serverID: server.serverID)
        store.setDefaultLibrarySortOrder(
            defaultSortOrder,
            providerID: server.providerID,
            serverID: server.serverID,
            sort: sort
        )
        store.clearLibrarySortOverrides(for: server.libraries.map(\.reference))
    }

    private func setDefaultSortOrder(_ order: LibraryPageSortOrder, for server: ConnectedServer) {
        defaultSortOrder = order
        store.setDefaultLibrarySort(defaultSort, providerID: server.providerID, serverID: server.serverID)
        store.setDefaultLibrarySortOrder(
            order,
            providerID: server.providerID,
            serverID: server.serverID,
            sort: defaultSort
        )
        store.clearLibrarySortOverrides(for: server.libraries.map(\.reference))
    }
}
