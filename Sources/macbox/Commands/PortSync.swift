import ArgumentParser
import Foundation

/// Internal background loop that keeps auto-forwarded ports in sync.
struct PortSync: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "port-sync",
        abstract: "Internal background port sync loop.",
        shouldDisplay: false
    )

    @Argument(help: "Distro name")
    var name: String

    /// Reconciles port forwards until the distro stops or the monitor is terminated.
    func run() async throws {
        while true {
            do {
                let host = HostInfo.current()
                let container = try await ContainerStateReader.inspect(name: name)
                guard container.status == "running" else {
                    AutoPortForwarding.stop(name: name)
                    return
                }
                _ = try DistroStateStore.load(name: name) ?? DistroState.legacy(name: name, host: host)
                try await AutoPortForwarding.syncOnce(name: name)
            } catch {
                AutoPortForwarding.stop(name: name)
                return
            }

            sleep(AutoPortForwarding.syncIntervalSeconds)
        }
    }
}
