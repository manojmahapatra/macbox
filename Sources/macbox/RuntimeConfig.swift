import Foundation

/// Builds the `container run` arguments for dynamic/runtime config.
/// This is the "runtime injection" half of the hybrid approach.
enum RuntimeConfig {

    static func runArgs(
        name: String,
        host: HostInfo,
        extraMounts: [String] = [],
        portForwards: [String] = [],
        cpus: Int? = nil,
        memory: String? = nil
    ) -> [String] {
        var args = [
            "container", "run",
            "--name", name,
            "--hostname", name,
            "--label", "macbox",
            "-d",
            "-v", "\(host.home):\(host.home):ro",
            "-p", "\(ImageBuilder.sshPort):\(ImageBuilder.sshPort)",
        ]

        // Resource limits
        if let cpus { args += ["--cpus", "\(cpus)"] }
        if let memory { args += ["--memory", memory] }

        // SSH agent forwarding
        if let sock = host.sshAuthSock {
            args += ["-v", "\(sock):/run/ssh-agent:ro"]
            args += ["-e", "SSH_AUTH_SOCK=/run/ssh-agent"]
        }

        // Inject host's public key for passwordless SSH
        let pubKeyPath = host.home + "/.ssh/id_ed25519.pub"
        let rsaPubKeyPath = host.home + "/.ssh/id_rsa.pub"
        let keyPath = FileManager.default.fileExists(atPath: pubKeyPath) ? pubKeyPath :
                      FileManager.default.fileExists(atPath: rsaPubKeyPath) ? rsaPubKeyPath : nil
        if let keyPath {
            args += ["-v", "\(keyPath):/home/\(host.username)/.ssh/authorized_keys:ro"]
        }

        // Forward useful host env
        for key in ["LANG", "TERM", "COLORTERM", "EDITOR"] {
            if let val = ProcessInfo.processInfo.environment[key] {
                args += ["-e", "\(key)=\(val)"]
            }
        }

        for pf in portForwards { args += ["-p", pf] }
        for mount in extraMounts { args += ["-v", mount] }

        args.append(ImageBuilder.imageTag(name: name, username: host.username))
        return args
    }

    static func execArgs(name: String, host: HostInfo) -> [String] {
        let shell = host.shell.hasSuffix("zsh") ? "/bin/zsh" :
                    host.shell.hasSuffix("fish") ? "/usr/bin/fish" : "/bin/bash"
        return ["container", "exec", "-it", "-u", host.username, name, shell, "-l"]
    }
}
