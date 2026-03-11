import ArgumentParser

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
        print("🗑 Removing container '\(name)'...")
        try await Shell.run(["container", "rm"] + forceFlag + [name])

        let host = HostInfo.current()
        let tag = ImageBuilder.imageTag(name: name, username: host.username)
        print("🗑 Removing image '\(tag)'...")
        try? await Shell.run("container", "rmi", tag)

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
        print("⏹ Stopping '\(name)'...")
        try await Shell.run("container", "stop", name)
    }
}
