import Darwin
import Foundation

/// Keeps localhost TCP forwards in sync with the ports a distro is listening on.
enum AutoPortForwarding {
    static let syncIntervalSeconds: UInt32 = 3
    private static let reservedPorts: Set<Int> = [ImageBuilder.sshPort]

    /// Starts the hidden port monitor for a distro if one is not already running.
    static func ensureMonitor(name: String) throws {
        var state = (try AutoPortForwardStore.load(name: name)) ?? AutoPortForwardState(name: name, monitorPID: nil, forwards: [])
        if let pid = state.monitorPID, isProcessAlive(pid) {
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: currentExecutablePath())
        process.arguments = ["port-sync", name]
        process.environment = ProcessInfo.processInfo.environment

        let devNull = FileHandle(forWritingAtPath: "/dev/null")
        process.standardInput = nil
        process.standardOutput = devNull
        process.standardError = devNull

        try process.run()
        state.monitorPID = process.processIdentifier
        try AutoPortForwardStore.save(state)
    }

    /// Stops the port monitor and any active SSH forwarders for a distro.
    static func stop(name: String) {
        let state = try? AutoPortForwardStore.load(name: name)
        state?.forwards.forEach { stopForwarder(pid: $0.pid) }
        if let pid = state?.monitorPID {
            stopForwarder(pid: pid)
        }
        try? AutoPortForwardStore.delete(name: name)
    }

    /// Reads listening TCP ports from the running distro.
    static func discoverPorts(name: String) async throws -> [Int] {
        let output = try await Shell.run(
            try ContainerCLI.command("exec", name, "sh", "-lc", "cat /proc/net/tcp /proc/net/tcp6"),
            quiet: true
        )
        let ports = output
            .split(separator: "\n")
            .compactMap(parseListeningPort(line:))
            .filter { !reservedPorts.contains($0) }
        return Array(Set(ports)).sorted()
    }

    /// Reconciles active SSH tunnels with the ports currently listening in the distro.
    static func syncOnce(name: String) async throws {
        let host = HostInfo.current()
        let distro = try DistroStateStore.load(name: name) ?? DistroState.legacy(name: name, host: host)
        let identity: ManagedSSHIdentity
        if let privateKeyPath = distro.sshPrivateKeyPath, let publicKeyPath = distro.sshPublicKeyPath {
            identity = ManagedSSHIdentity(name: name, privateKeyPath: privateKeyPath, publicKeyPath: publicKeyPath)
        } else {
            identity = try await ManagedSSHIdentity.ensure(name: name)
        }

        var state = (try AutoPortForwardStore.load(name: name)) ?? AutoPortForwardState(name: name, monitorPID: getpid(), forwards: [])
        state.monitorPID = getpid()

        let currentPorts = try await discoverPorts(name: name)
        let currentSet = Set(currentPorts)

        var activeForwards: [ForwardedPort] = []
        for forward in state.forwards {
            guard currentSet.contains(forward.containerPort), isProcessAlive(forward.pid) else {
                stopForwarder(pid: forward.pid)
                continue
            }
            activeForwards.append(forward)
        }

        let existingPorts = Set(activeForwards.map(\.containerPort))
        let newContainerPorts = currentPorts.filter { !existingPorts.contains($0) }

        for containerPort in newContainerPorts {
            let reserved = reservedHostPorts(excludingDistro: name)
                .union(activeForwards.map(\.hostPort))
                .union([distro.sshHostPort])
            let hostPort = try PortAllocator.preferredOrEphemeral(preferred: containerPort, reserved: reserved)
            let pid = try startForwarder(
                name: name,
                username: host.username,
                sshPort: distro.sshHostPort,
                privateKeyPath: identity.privateKeyPath,
                hostPort: hostPort,
                containerPort: containerPort
            )
            activeForwards.append(ForwardedPort(containerPort: containerPort, hostPort: hostPort, pid: pid))
        }

        state.forwards = activeForwards.sorted { $0.containerPort < $1.containerPort }
        try AutoPortForwardStore.save(state)
    }

    private static func startForwarder(
        name: String,
        username: String,
        sshPort: Int,
        privateKeyPath: String,
        hostPort: Int,
        containerPort: Int
    ) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
            "-i", privateKeyPath,
            "-o", "IdentitiesOnly=yes",
            "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=/dev/null",
            "-o", "LogLevel=ERROR",
            "-o", "ExitOnForwardFailure=yes",
            "-N",
            "-L", "127.0.0.1:\(hostPort):127.0.0.1:\(containerPort)",
            "-p", "\(sshPort)",
            "\(username)@localhost",
        ]

        let devNull = FileHandle(forWritingAtPath: "/dev/null")
        process.standardInput = nil
        process.standardOutput = devNull
        process.standardError = devNull
        try process.run()
        Thread.sleep(forTimeInterval: 0.2)

        guard process.isRunning else {
            throw MacboxError.portForwardFailed(name, containerPort)
        }

        return process.processIdentifier
    }

    private static func reservedHostPorts(excludingDistro name: String) -> Set<Int> {
        let sshPorts = DistroStateStore.all()
            .filter { $0.name != name }
            .map(\.sshHostPort)
        let appPorts = AutoPortForwardStore.all()
            .filter { $0.name != name }
            .flatMap { $0.forwards.map(\.hostPort) }
        return Set(sshPorts + appPorts)
    }

    private static func currentExecutablePath() -> String {
        let raw = CommandLine.arguments[0]
        if raw.hasPrefix("/") {
            return raw
        }
        return URL(fileURLWithPath: raw, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
            .standardizedFileURL
            .path
    }

    private static func isProcessAlive(_ pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        if kill(pid, 0) == 0 { return true }
        return errno == EPERM
    }

    private static func stopForwarder(pid: Int32) {
        guard pid > 0 else { return }
        _ = kill(pid, SIGTERM)
    }

    private static func parseListeningPort(line: Substring) -> Int? {
        let parts = line.split(whereSeparator: \.isWhitespace)
        guard parts.count >= 4 else { return nil }
        guard parts[3] == "0A" else { return nil }
        let address = parts[1].split(separator: ":")
        guard address.count == 2 else { return nil }
        return Int(address[1], radix: 16)
    }
}
