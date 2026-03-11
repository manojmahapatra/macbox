import Foundation

/// Generates a Dockerfile that bakes static per-user config into the image.
/// This is the "image-first" half of the hybrid approach.
enum ImageBuilder {

    static let sshPort = 2222

    /// Returns the Dockerfile content for a per-user layer on top of `base`.
    static func dockerfile(base: String, host: HostInfo) -> String {
        let shell = linuxShell(from: host.shell)
        let shellPkg = shell == "/bin/bash" ? "" : shell.split(separator: "/").last.map(String.init) ?? ""
        return """
        FROM \(base)

        # Install essentials: sudo, user shell, openssh-server
        RUN if command -v apt-get >/dev/null 2>&1; then \\
              apt-get update -qq && apt-get install -y -qq sudo openssh-server \(shellPkg) && rm -rf /var/lib/apt/lists/* && mkdir -p /run/sshd; \\
            elif command -v apk >/dev/null 2>&1; then \\
              apk add --no-cache sudo openssh-server \(shellPkg) && ssh-keygen -A; \\
            elif command -v dnf >/dev/null 2>&1; then \\
              dnf install -y sudo openssh-server \(shellPkg) && dnf clean all && ssh-keygen -A; \\
            fi

        # Create user matching host UID/GID
        RUN groupadd -g \(host.gid) \(host.username) 2>/dev/null || true && \\
            useradd -u \(host.uid) -g \(host.gid) -d /home/\(host.username) -s \(shell) -m -N \(host.username) 2>/dev/null || true && \\
            echo '\(host.username) ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/\(host.username) && \\
            mkdir -p /home/\(host.username)/.ssh && chown \(host.uid):\(host.gid) /home/\(host.username)/.ssh && chmod 700 /home/\(host.username)/.ssh

        # Configure sshd: key-only auth on port \(sshPort)
        RUN sed -i 's/#Port 22/Port \(sshPort)/' /etc/ssh/sshd_config 2>/dev/null; \\
            echo 'Port \(sshPort)' >> /etc/ssh/sshd_config; \\
            echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config; \\
            echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config

        # Entrypoint: start sshd then keep container alive
        RUN printf '#!/bin/sh\\n/usr/sbin/sshd 2>/dev/null; exec sleep infinity\\n' > /usr/local/bin/macbox-init.sh && \\
            chmod +x /usr/local/bin/macbox-init.sh

        USER root
        EXPOSE \(sshPort)
        CMD ["/usr/local/bin/macbox-init.sh"]
        """
    }

    /// Build the per-user image using `container build`.
    static func build(name: String, base: String, host: HostInfo) async throws {
        let tag = imageTag(name: name, username: host.username)
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("macbox-\(name)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let dockerfilePath = tmpDir.appendingPathComponent("Dockerfile")
        try dockerfile(base: base, host: host).write(to: dockerfilePath, atomically: true, encoding: .utf8)

        try await Shell.run("container", "build", "--tag", tag, tmpDir.path())
    }

    static func imageTag(name: String, username: String) -> String {
        "macbox-\(name)-\(username):latest"
    }

    private static func linuxShell(from macShell: String) -> String {
        if macShell.hasSuffix("zsh") { return "/bin/zsh" }
        if macShell.hasSuffix("fish") { return "/usr/bin/fish" }
        return "/bin/bash"
    }
}
