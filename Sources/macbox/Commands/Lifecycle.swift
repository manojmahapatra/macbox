import ArgumentParser
import Foundation

/// Removes a distro, its image, and all local `macbox` metadata.
struct Remove: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Remove a distro and its image."
    )

    @Argument(help: "Distro name")
    var name: String

    @Flag(help: "Force remove even if running")
    var force: Bool = false

    /// Tears down the container, image, managed SSH assets, and saved state.
    func run() async throws {
        let forceFlag = force ? ["-f"] : []
        AutoPortForwarding.stop(name: name)
        print("🗑 Removing container '\(name)'...")
        try await Shell.run(try ContainerCLI.command(["rm"] + forceFlag + [name]))

        let host = HostInfo.current()
        let state = try DistroStateStore.load(name: name)
        let tag = state?.imageTag ?? ImageBuilder.imageTag(name: name, username: host.username)
        print("🗑 Removing image '\(tag)'...")
        do {
            _ = try await Shell.run(try ContainerCLI.command("image", "delete", "--force", tag), quiet: true)
        } catch {
            fputs("warning: failed to remove image '\(tag)': \(error)\n", stderr)
        }

        try? ManagedSSHIdentity.delete(name: name)
        try? ManagedSSHConfig.delete(name: name)
        try? DistroStateStore.delete(name: name)

        print("✅ Distro '\(name)' removed.")
    }
}

/// Stops a running distro without deleting its image or saved metadata.
struct Stop: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Stop a running distro."
    )

    @Argument(help: "Distro name")
    var name: String

    /// Stops the distro and any background port forwarders.
    func run() async throws {
        AutoPortForwarding.stop(name: name)
        print("⏹ Stopping '\(name)'...")
        try await Shell.run(try ContainerCLI.command("stop", name))
    }
}
