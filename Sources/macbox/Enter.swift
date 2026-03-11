import ArgumentParser

struct Enter: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Enter a running distro (starts it if stopped)."
    )

    @Argument(help: "Distro name")
    var name: String

    @Flag(help: "Connect via SSH instead of container exec")
    var ssh: Bool = false

    func run() async throws {
        let host = HostInfo.current()

        // Start if not running
        let status = try await Shell.run(["container", "inspect", "--format", "{{.State.Status}}", name], quiet: true)
        if status != "running" {
            print("▶ Starting '\(name)'...")
            try await Shell.run("container", "start", name)
        }

        if ssh {
            try await Shell.exec([
                "ssh", "-p", "\(ImageBuilder.sshPort)",
                "-o", "StrictHostKeyChecking=no",
                "-o", "UserKnownHostsFile=/dev/null",
                "-o", "LogLevel=ERROR",
                "\(host.username)@localhost"
            ])
        } else {
            let args = RuntimeConfig.execArgs(name: name, host: host)
            try await Shell.exec(args)
        }
    }
}
