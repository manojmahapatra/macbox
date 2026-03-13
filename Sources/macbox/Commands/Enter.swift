import ArgumentParser

/// Opens an interactive session in a distro via `container exec` or SSH.
struct Enter: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Enter a running distro (starts it if stopped)."
    )

    @Argument(help: "Distro name")
    var name: String

    @Flag(help: "Connect via SSH instead of container exec")
    var ssh: Bool = false

    /// Ensures the distro is running and connects using the requested access mode.
    func run() async throws {
        let host = HostInfo.current()
        var state = try DistroStateStore.load(name: name) ?? DistroState.legacy(name: name, host: host)
        let identity: ManagedSSHIdentity
        if let privateKeyPath = state.sshPrivateKeyPath, let publicKeyPath = state.sshPublicKeyPath {
            identity = ManagedSSHIdentity(name: name, privateKeyPath: privateKeyPath, publicKeyPath: publicKeyPath)
        } else {
            identity = try await ManagedSSHIdentity.ensure(name: name)
            state = DistroState(
                name: state.name,
                imageTag: state.imageTag,
                baseImage: state.baseImage,
                sshHostPort: state.sshHostPort,
                sshContainerPort: state.sshContainerPort,
                shell: state.shell,
                sshPrivateKeyPath: identity.privateKeyPath,
                sshPublicKeyPath: identity.publicKeyPath
            )
            try? DistroStateStore.save(state)
        }
        try? ManagedSSHConfig.sync(
            name: name,
            username: host.username,
            port: state.sshHostPort,
            privateKeyPath: identity.privateKeyPath
        )
        try? AutoPortForwarding.ensureMonitor(name: name)

        // Start if not running
        let container = try await ContainerStateReader.inspect(name: name)
        if container.status != "running" {
            print("▶ Starting '\(name)'...")
            try await Shell.run(try ContainerCLI.command("start", name))
            try? AutoPortForwarding.ensureMonitor(name: name)
        }
        try await AuthorizedKeys.sync(name: name, host: host, publicKeyPath: identity.publicKeyPath)

        if ssh {
            try await Shell.exec([
                "/usr/bin/ssh",
                "-i", identity.privateKeyPath,
                "-o", "IdentitiesOnly=yes",
                "-o", "StrictHostKeyChecking=no",
                "-o", "UserKnownHostsFile=/dev/null",
                "-o", "LogLevel=ERROR",
                "-p", "\(state.sshHostPort)",
                "\(host.username)@localhost"
            ])
        } else {
            let args = try RuntimeConfig.execArgs(name: name, host: host, preferredShell: state.shell)
            try await Shell.exec(args)
        }
    }
}
