import ArgumentParser
import Foundation

struct Create: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Create a new distro from a container image or config file."
    )

    @Argument(help: "Base image (e.g. ubuntu:24.04) — ignored if --config is used")
    var image: String?

    @Argument(help: "Name for this distro")
    var name: String

    @Option(name: .shortAndLong, help: "Path to macbox.json config file")
    var config: String?

    @Option(name: .shortAndLong, help: "Additional host paths to mount (path:path[:ro])")
    var mount: [String] = []

    @Option(name: .shortAndLong, help: "Port forwards (hostPort:containerPort)")
    var publish: [String] = []

    @Option(help: "Provisioning command to run after creation")
    var provision: [String] = []

    @Option(help: "CPU limit")
    var cpus: Int?

    @Option(help: "Memory limit (e.g. 4g, 2048m)")
    var memory: String?

    @Flag(help: "Mount home directory read-write instead of read-only")
    var homeRW: Bool = false

    func run() async throws {
        let host = HostInfo.current()

        // Merge config file with CLI flags (CLI wins)
        var resolvedImage = image
        var allMounts = mount
        var allPorts = publish
        var allProvision = provision
        var resolvedCpus = cpus
        var resolvedMemory = memory
        var resolvedHomeRW = homeRW

        if let configPath = config {
            let cfg = try DistroConfig.load(from: configPath)
            resolvedImage = resolvedImage ?? cfg.image
            allMounts += cfg.mounts ?? []
            allPorts += cfg.ports ?? []
            allProvision += cfg.provision ?? []
            resolvedCpus = resolvedCpus ?? cfg.cpus
            resolvedMemory = resolvedMemory ?? cfg.memory
            resolvedHomeRW = resolvedHomeRW || (cfg.homeRW ?? false)
        }

        guard let finalImage = resolvedImage else {
            throw ValidationError("Image is required (provide as argument or in config file)")
        }

        print("🔨 Building per-user image for '\(name)' from \(finalImage)...")
        try await ImageBuilder.build(name: name, base: finalImage, host: host)

        print("🚀 Creating container '\(name)'...")
        var args = RuntimeConfig.runArgs(
            name: name, host: host,
            extraMounts: allMounts, portForwards: allPorts,
            cpus: resolvedCpus, memory: resolvedMemory
        )

        if resolvedHomeRW {
            args = args.map { $0 == "\(host.home):\(host.home):ro" ? "\(host.home):\(host.home):rw" : $0 }
        }

        try await Shell.run(args)

        // Run provisioning commands inside the container
        if !allProvision.isEmpty {
            print("📦 Running provisioning...")
            for cmd in allProvision {
                try await Shell.run(
                    "container", "exec", name,
                    "bash", "-c", cmd
                )
            }
        }

        print("✅ Distro '\(name)' ready.")
        print("   Enter:   macbox enter \(name)")
        print("   SSH:     ssh -p \(ImageBuilder.sshPort) \(host.username)@localhost")
        print("   VS Code: code --remote ssh-remote+\(host.username)@localhost:\(ImageBuilder.sshPort) /home/\(host.username)")
    }
}
