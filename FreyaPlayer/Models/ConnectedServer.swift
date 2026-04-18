import Foundation

struct ConnectedServer: Equatable, Identifiable {
    let providerID: MediaProviderID
    let serverID: String
    let serverName: String
    let accountName: String
    let libraries: [LibraryShelf]

    var id: String {
        "\(providerID.rawValue):\(serverID)"
    }

    func settingLibraries(_ libraries: [LibraryShelf]) -> ConnectedServer {
        ConnectedServer(
            providerID: providerID,
            serverID: serverID,
            serverName: serverName,
            accountName: accountName,
            libraries: libraries
        )
    }
}
