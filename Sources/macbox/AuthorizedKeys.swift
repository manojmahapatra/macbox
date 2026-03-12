import Foundation

enum AuthorizedKeys {
    static func sync(name: String, host: HostInfo, publicKeyPath: String) async throws {
        let source = shellQuote(publicKeyPath)
        let target = shellQuote("/home/\(host.username)/.ssh/authorized_keys")
        let script = """
        install -d -m 700 -o \(host.uid) -g \(host.gid) /home/\(host.username)/.ssh && \
        install -m 600 -o \(host.uid) -g \(host.gid) \(source) \(target)
        """

        try await Shell.run(try ContainerCLI.command("exec", name, "sh", "-lc", script))
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }
}
