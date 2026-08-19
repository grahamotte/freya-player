import Combine
import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var isOffline = false

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isOffline = Self.isOffline(pathStatus: path.status)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    static func isOffline(pathStatus: NWPath.Status) -> Bool {
        pathStatus == .unsatisfied
    }
}
