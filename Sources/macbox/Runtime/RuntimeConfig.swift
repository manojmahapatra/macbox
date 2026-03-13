import Foundation

/// Builds the `container run` arguments for dynamic/runtime config.
/// This is the "runtime injection" half of the hybrid approach.
enum RuntimeConfig {

    /// Builds the `container run` arguments that apply host integration at startup.
    static func runArgs(
        name: String,
        host: HostInfo,
        extraMounts: [String] = [],
        portForwards: [String] = [],
        cpus: Int? = nil,
        memory: String? = nil,
        sshHostPort: Int,
        homeReadWrite: Bool = false,
        containerExecutable: String? = nil
    ) throws -> [String] {
        var args = try ContainerCLI.command([
            "run",
            "--name", name,
            "--label", "macbox",
            "--label", "macbox.ssh-host-port=\(sshHostPort)",
            "-d",
            "--mount", bindMount(source: host.home, target: host.home, readOnly: !homeReadWrite),
            "--publish", "127.0.0.1:\(sshHostPort):\(ImageBuilder.sshPort)",
        ], executable: containerExecutable)

        // Resource limits
        if let cpus { args += ["--cpus", "\(cpus)"] }
        if let memory { args += ["--memory", memory] }

        // SSH agent forwarding
        if host.sshAuthSock != nil {
            args.append("--ssh")
        }

        // Forward useful host env
        for key in ["LANG", "TERM", "COLORTERM", "EDITOR"] {
            if let val = ProcessInfo.processInfo.environment[key] {
                args += ["-e", "\(key)=\(val)"]
            }
        }

        for pf in portForwards { args += ["--publish", pf] }
        for mount in extraMounts { args += ["--mount", try bindMount(spec: mount)] }

        args.append(ImageBuilder.imageTag(name: name, username: host.username))
        return args
    }

    /// Builds the `container exec` arguments used for an interactive shell session.
    static func execArgs(
        name: String,
        host: HostInfo,
        preferredShell: String? = nil,
        containerExecutable: String? = nil
    ) throws -> [String] {
        let primaryShell = preferredShell ?? containerShell(from: host.shell)
        let fallbackScript = [
            primaryShell,
            "/bin/zsh",
            "/usr/bin/fish",
            "/bin/bash",
            "/bin/sh",
        ]
            .uniqued()
            .map { "if [ -x \($0) ]; then exec \($0) -l; fi" }
            .joined(separator: "; ")

        return try ContainerCLI.command([
            "exec", "-it", "-u", host.username, name,
            "/bin/sh", "-lc", "\(fallbackScript); exec /bin/sh -l"
        ], executable: containerExecutable)
    }

    /// Maps the host login shell to a Linux shell path likely to exist in the distro.
    static func containerShell(from hostShell: String) -> String {
        if hostShell.hasSuffix("zsh") { return "/bin/zsh" }
        if hostShell.hasSuffix("fish") { return "/usr/bin/fish" }
        return "/bin/bash"
    }

    private static func bindMount(spec: String) throws -> String {
        let components = spec.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard components.count == 2 || components.count == 3 else {
            throw MacboxError.invalidMountSpec(spec)
        }

        let source = expandPath(components[0])
        let target = components[1]
        let readOnly = components.count == 3 && components[2].lowercased() == "ro"
        return bindMount(source: source, target: target, readOnly: readOnly)
    }

    private static func bindMount(source: String, target: String, readOnly: Bool) -> String {
        var pieces = [
            "type=bind",
            "source=\(expandPath(source))",
            "target=\(target)",
        ]
        if readOnly {
            pieces.append("readonly")
        }
        return pieces.joined(separator: ",")
    }

    private static func expandPath(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
