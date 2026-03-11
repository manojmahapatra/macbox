import ArgumentParser

struct Create: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Create a new distro from a container image."
    )

    @Argument(help: "Base image (e.g. ubuntu:24.04, alpine:latest)")
    var image: String

    @Argument(help: "Name for this distro")
    var name: String

    @Option(name: .shortAndLong, help: "Additional host paths to mount (path:path[:ro])")
    var mount: [String] = []

    @Option(name: .shortAndLong, help: "Port forwards (hostPort:containerPort)")
    var publish: [String] = []

    @Flag(help: "Mount home directory read-write instead of read-only")
    var homeRW: Bool = false

    func run() async throws {
        let host = HostInfo.current()

        print("🔨 Building per-user image for '\(name)' from \(image)...")
        try await ImageBuilder.build(name: name, base: image, host: host)

        print("🚀 Creating container '\(name)'...")
        var args = RuntimeConfig.runArgs(name: name, host: host, extraMounts: mount, portForwards: publish)

        if homeRW {
            args = args.map { $0 == "\(host.home):\(host.home):ro" ? "\(host.home):\(host.home):rw" : $0 }
        }

        try await Shell.run(args)

        print("✅ Distro '\(name)' ready.")
        print("   Enter:  macbox enter \(name)")
        print("   SSH:    ssh -p \(ImageBuilder.sshPort) \(host.username)@localhost")
        print("   VS Code: code --remote ssh-remote+\(host.username)@localhost:\(ImageBuilder.sshPort) /home/\(host.username)")
    }
}
