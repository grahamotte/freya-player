import Foundation

struct ConnectedServer: Equatable, Identifiable {
    let providerID: MediaProviderID
    let serverID: String
    let serverName: String
    let serverURL: String
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
            serverURL: serverURL,
            accountName: accountName,
            libraries: libraries
        )
    }
}
