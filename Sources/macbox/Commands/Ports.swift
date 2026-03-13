import ArgumentParser

/// Displays the TCP ports `macbox` is currently forwarding for a distro.
struct Ports: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show automatically forwarded app ports for a distro."
    )

    @Argument(help: "Distro name")
    var name: String

    /// Prints the host-to-container TCP forwards recorded for a distro.
    func run() async throws {
        let state = try AutoPortForwardStore.load(name: name) ?? AutoPortForwardState(name: name, monitorPID: nil, forwards: [])
        if state.forwards.isEmpty {
            print("No auto-forwarded app ports for '\(name)'.")
            return
        }

        print("HOST  CONTAINER")
        for forward in state.forwards.sorted(by: { $0.hostPort < $1.hostPort }) {
            print("\(forward.hostPort)  \(forward.containerPort)")
        }
    }
}
