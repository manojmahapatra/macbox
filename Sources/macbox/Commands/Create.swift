import ArgumentParser
import Foundation

/// Creates a new distro, provisions its runtime integration, and persists local metadata.
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

    @Flag(name: .customLong("home-rw"), help: "Mount home directory read-write instead of read-only")
    var homeRW: Bool = false

    @Flag(name: .customLong("home-ro"), help: "Force home directory to stay read-only")
    var homeRO: Bool = false

    /// Builds the per-user image, starts the distro, and wires up SSH and port state.
    func run() async throws {
        let host = HostInfo.current()
        let identity = try await ManagedSSHIdentity.ensure(name: name)
        let resolvedHomePreference = try resolveHomePreference()

        let cfg = try config.map(DistroConfig.load)

        let resolvedImage = image ?? cfg?.image
        let allMounts = mount.isEmpty ? (cfg?.mounts ?? []) : mount
        let allPorts = publish.isEmpty ? (cfg?.ports ?? []) : publish
        let allProvision = provision.isEmpty ? (cfg?.provision ?? []) : provision
        let resolvedCpus = cpus ?? cfg?.cpus
        let resolvedMemory = memory ?? cfg?.memory
        let resolvedHomeRW = resolvedHomePreference ?? cfg?.homeRW ?? false

        guard let finalImage = resolvedImage else {
            throw ValidationError("Image is required (provide as argument or in config file)")
        }

        let existingPorts = Set(DistroStateStore.all().map(\.sshHostPort))
        let sshHostPort = try PortAllocator.nextAvailableSSHPort(reserved: existingPorts)
        let imageTag = ImageBuilder.imageTag(name: name, username: host.username)

        print("🔨 Building per-user image for '\(name)' from \(finalImage)...")
        try await ImageBuilder.build(name: name, base: finalImage, host: host)

        print("🚀 Creating container '\(name)'...")
        let args = try RuntimeConfig.runArgs(
            name: name, host: host,
            extraMounts: allMounts, portForwards: allPorts,
            cpus: resolvedCpus, memory: resolvedMemory,
            sshHostPort: sshHostPort,
            homeReadWrite: resolvedHomeRW
        )

        try await Shell.run(args)
        try await AuthorizedKeys.sync(name: name, host: host, publicKeyPath: identity.publicKeyPath)

        let state = DistroState(
            name: name,
            imageTag: imageTag,
            baseImage: finalImage,
            sshHostPort: sshHostPort,
            sshContainerPort: ImageBuilder.sshPort,
            shell: RuntimeConfig.containerShell(from: host.shell),
            sshPrivateKeyPath: identity.privateKeyPath,
            sshPublicKeyPath: identity.publicKeyPath
        )
        try DistroStateStore.save(state)
        try ManagedSSHConfig.sync(
            name: name,
            username: host.username,
            port: sshHostPort,
            privateKeyPath: identity.privateKeyPath
        )
        try AutoPortForwarding.ensureMonitor(name: name)

        // Run provisioning commands inside the container
        if !allProvision.isEmpty {
            print("📦 Running provisioning...")
            for cmd in allProvision {
                try await Shell.run(
                    try ContainerCLI.command(
                        "exec", name,
                        "sh", "-lc", cmd
                    )
                )
            }
        }

        print("✅ Distro '\(name)' ready.")
        print("   Enter:   macbox enter \(name)")
        print("   SSH:     ssh -i \(identity.privateKeyPath) -p \(sshHostPort) \(host.username)@localhost")
        print("   Alias:   ssh -F \(ManagedSSHConfig.configPath()) \(ManagedSSHConfig.hostAlias(for: name))")
        print("   Ports:   macbox ports \(name)")
        print("   VS Code: code --remote ssh-remote+\(host.username)@localhost:\(sshHostPort) /home/\(host.username)")
    }

    /// Resolves mutually exclusive home mount flags into a single read/write preference.
    private func resolveHomePreference() throws -> Bool? {
        if homeRW && homeRO {
            throw ValidationError("Choose either --home-rw or --home-ro, not both")
        }
        if homeRW { return true }
        if homeRO { return false }
        return nil
    }
}
