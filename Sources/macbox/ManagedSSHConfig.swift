import Foundation

enum ManagedSSHConfig {
    static func sync(name: String, username: String, port: Int, privateKeyPath: String) throws {
        let fm = FileManager.default
        let directory = fragmentsDirectory()
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: sshRootDirectory().path)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)

        let fragment = fragmentURL(for: name)
        try renderFragment(name: name, username: username, port: port, privateKeyPath: privateKeyPath)
            .write(to: fragment, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fragment.path)

        let config = configURL()
        try renderAggregateConfig().write(to: config, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: config.path)
    }

    static func delete(name: String) throws {
        let fm = FileManager.default
        let fragment = fragmentURL(for: name)
        if fm.fileExists(atPath: fragment.path) {
            try fm.removeItem(at: fragment)
        }

        let config = configURL()
        if fm.fileExists(atPath: config.path) {
            try renderAggregateConfig().write(to: config, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: config.path)
        }
    }

    static func hostAlias(for name: String) -> String {
        "macbox-\(name)"
    }

    static func configPath() -> String {
        configURL().path
    }

    static func fragmentPath(for name: String) -> String {
        fragmentURL(for: name).path
    }

    static func renderFragment(name: String, username: String, port: Int, privateKeyPath: String) -> String {
        """
        Host \(hostAlias(for: name))
          HostName 127.0.0.1
          User \(username)
          Port \(port)
          IdentityFile "\(privateKeyPath)"
          IdentitiesOnly yes
          StrictHostKeyChecking no
          UserKnownHostsFile /dev/null
          LogLevel ERROR
        
        """
    }

    private static func renderAggregateConfig() -> String {
        """
        Include "\(fragmentsDirectory().path)/*.conf"
        """
    }

    private static func sshRootDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("macbox", isDirectory: true)
            .appendingPathComponent("ssh", isDirectory: true)
    }

    private static func fragmentsDirectory() -> URL {
        sshRootDirectory().appendingPathComponent("conf.d", isDirectory: true)
    }

    private static func configURL() -> URL {
        sshRootDirectory().appendingPathComponent("config")
    }

    private static func fragmentURL(for name: String) -> URL {
        fragmentsDirectory().appendingPathComponent("\(name).conf")
    }
}
