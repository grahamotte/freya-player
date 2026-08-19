import SwiftUI

struct ServerManagementPanel: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var cache: LibraryCache
    @Binding var path: [AppRoute]

    @State private var isShowingDeactivateAlert = false

    init(model: AppModel, path: Binding<[AppRoute]>) {
        self.model = model
        self.cache = model.libraryCache
        self._path = path
    }

    var body: some View {
        ScrollView {
            if let server = model.connectedServer {
                VStack(alignment: .leading, spacing: 24) {
                    ServerManagementServerSection(
                        server: server,
                        onDeactivate: {
                            isShowingDeactivateAlert = true
                        }
                    )

                    ServerManagementSection("Cache") {
                        VStack(alignment: .leading, spacing: 14) {
                            ServerManagementControlRow("Application Cache Version") {
                                Text(String(cache.applicationCacheVersion))
                                    .monospacedDigit()
                            }

                            ServerManagementControlRow("Cache File Version") {
                                Text(cache.fileCacheVersion.map { String($0) } ?? "Missing")
                                    .monospacedDigit()
                            }

                            ServerManagementControlRow("Cache Size") {
                                Text(cache.formattedStorageSize)
                                    .monospacedDigit()
                            }

                            Button("Clear Cache") {
                                model.clearCache()
                            }
                            .buttonStyle(MediaGlassButtonStyle())
                        }
                    }

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
                .padding(PlatformMetadata.isPhone ? 16 : 32)
                .padding(PlatformMetadata.isPhone ? 16 : 48)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
        .alert("Deactivate Server?", isPresented: $isShowingDeactivateAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Deactivate", role: .destructive) {
                model.disconnectCurrentServer()
                path.removeAll()
            }
        } message: {
            Text("This removes every server and all Freya Player data from this device.")
        }
    }
}
