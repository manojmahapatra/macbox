import Foundation

/// Host environment info collected once and used for both
/// image building (static) and container launch (dynamic).
struct HostInfo: Sendable {
    let username: String
    let uid: UInt32
    let gid: UInt32
    let home: String
    let shell: String
    let sshAuthSock: String?

    /// Captures the current macOS user, home directory, shell, and SSH agent socket.
    static func current() -> HostInfo {
        HostInfo(
            username: NSUserName(),
            uid: getuid(),
            gid: getgid(),
            home: NSHomeDirectory(),
            shell: ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh",
            sshAuthSock: ProcessInfo.processInfo.environment["SSH_AUTH_SOCK"]
        )
    }
}
