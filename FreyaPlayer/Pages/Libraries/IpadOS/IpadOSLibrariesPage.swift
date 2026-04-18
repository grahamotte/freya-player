import SwiftUI

#if os(iOS)
struct LibrariesPage: View {
    @ObservedObject var model: AppModel
    let server: ConnectedServer
    @Binding var path: [AppRoute]

    private var visibleLibraries: [LibraryShelf] {
        server.libraries.filter { !$0.isHidden }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(server.serverName)
                        .font(.largeTitle.weight(.bold))

                    Text(server.accountName)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.horizontal, 32)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                    ForEach(visibleLibraries) { shelf in
                        NavigationLink(value: shelf.reference.route) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(shelf.title)
                                    .font(.title3.weight(.semibold))
                                    .lineLimit(2)

                                Text("\(shelf.items.count) recent")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
                            .padding(20)
                            .background(PanelBackground())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 32)

                ForEach(visibleLibraries) { shelf in
                    VStack(alignment: .leading, spacing: 16) {
                        Text(shelf.title)
                            .font(.title2.weight(.semibold))
                            .padding(.horizontal, 32)

                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(Array(shelf.items.prefix(20))) { item in
                                    NavigationLink(value: item.route) {
                                        LibraryItemCard(item: item, artworkStyle: shelf.reference.artworkStyle)
                                            .frame(width: shelf.reference.artworkStyle == .poster ? 180 : 280)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.leading, 32)
                            .padding(.vertical, 4)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .background(LibrariesAmbientBackground())
        .toolbar {
            Button("Settings") {
                path.append(server.providerID.settingsRoute)
            }
        }
        .task(id: server.id) {
            await PollingLoop.run {
                await model.refreshConnection()
            }
        }
    }
}
#endif
