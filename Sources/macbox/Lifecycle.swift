import ArgumentParser
import Foundation

struct Remove: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Remove a distro and its image."
    )

    @Argument(help: "Distro name")
    var name: String

    @Flag(help: "Force remove even if running")
    var force: Bool = false

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

struct Stop: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Stop a running distro."
    )

    @Argument(help: "Distro name")
    var name: String

    func run() async throws {
        AutoPortForwarding.stop(name: name)
        print("⏹ Stopping '\(name)'...")
        try await Shell.run(try ContainerCLI.command("stop", name))
    }
}
