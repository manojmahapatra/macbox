import Foundation

/// Generates a Dockerfile that bakes static per-user config into the image.
/// This is the "image-first" half of the hybrid approach.
enum ImageBuilder {

    static let sshPort = 2222

    /// Returns the Dockerfile content for a per-user layer on top of `base`.
    static func dockerfile(base: String, host: HostInfo) -> String {
        let shell = linuxShell(from: host.shell)
        let shellPkg = shellPackage(for: shell)
        return """
        FROM \(base)

        # Install essentials: sudo, user shell, openssh-server
        RUN if command -v apt-get >/dev/null 2>&1; then \\
              apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq sudo openssh-server \(shellPkg) && rm -rf /var/lib/apt/lists/*; \\
            elif command -v apk >/dev/null 2>&1; then \\
              apk add --no-cache sudo openssh-server \(shellPkg); \\
            elif command -v dnf >/dev/null 2>&1; then \\
              dnf install -y sudo openssh-server \(shellPkg) && dnf clean all; \\
            elif command -v yum >/dev/null 2>&1; then \\
              yum install -y sudo openssh-server \(shellPkg) && yum clean all; \\
            else \\
              echo "Unsupported base image: missing apt-get/apk/dnf/yum" >&2; exit 1; \\
            fi
        RUN mkdir -p /run/sshd /etc/sudoers.d && ssh-keygen -A

        # Create user matching host UID/GID
        RUN if command -v useradd >/dev/null 2>&1; then \\
              groupadd -g \(host.gid) \(host.username) 2>/dev/null || true; \\
              id -u \(host.username) >/dev/null 2>&1 || useradd -u \(host.uid) -g \(host.gid) -d /home/\(host.username) -s \(shell) -m -N \(host.username); \\
            elif command -v addgroup >/dev/null 2>&1 && command -v adduser >/dev/null 2>&1; then \\
              addgroup -g \(host.gid) \(host.username) 2>/dev/null || true; \\
              id -u \(host.username) >/dev/null 2>&1 || adduser -D -h /home/\(host.username) -s \(shell) -G \(host.username) -u \(host.uid) \(host.username); \\
            else \\
              echo "No supported user creation tools in base image" >&2; exit 1; \\
            fi && \\
            echo '\(host.username) ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/\(host.username) && \\
            chmod 0440 /etc/sudoers.d/\(host.username) && \\
            mkdir -p /home/\(host.username)/.ssh && touch /home/\(host.username)/.zshrc && chown -R \(host.uid):\(host.gid) /home/\(host.username) && chmod 700 /home/\(host.username)/.ssh

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

    /// Builds the per-user image using `container build`.
    static func build(name: String, base: String, host: HostInfo) async throws {
        let tag = imageTag(name: name, username: host.username)
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("macbox-\(name)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let dockerfilePath = tmpDir.appendingPathComponent("Dockerfile")
        try dockerfile(base: base, host: host).write(to: dockerfilePath, atomically: true, encoding: .utf8)

        try await Shell.run(try ContainerCLI.command("build", "--tag", tag, tmpDir.path()))
    }

    /// Returns the local image tag used for a distro’s baked user image.
    static func imageTag(name: String, username: String) -> String {
        "macbox-\(name)-\(username):latest"
    }

    private static func linuxShell(from macShell: String) -> String {
        if macShell.hasSuffix("zsh") { return "/bin/zsh" }
        if macShell.hasSuffix("fish") { return "/usr/bin/fish" }
        return "/bin/bash"
    }

    private static func shellPackage(for shell: String) -> String {
        if shell.hasSuffix("zsh") { return "zsh" }
        if shell.hasSuffix("fish") { return "fish" }
        return "bash"
    }
}
