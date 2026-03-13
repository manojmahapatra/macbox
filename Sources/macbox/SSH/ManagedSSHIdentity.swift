import Foundation

/// Represents the SSH keypair `macbox` manages for a single distro.
struct ManagedSSHIdentity: Sendable, Equatable {
    let name: String
    let privateKeyPath: String
    let publicKeyPath: String

    /// Creates the keypair for a distro if needed and returns its paths.
    static func ensure(name: String) async throws -> ManagedSSHIdentity {
        let directory = storageDirectory().appendingPathComponent(name, isDirectory: true)
        let privateKey = directory.appendingPathComponent("id_ed25519")
        let publicKey = directory.appendingPathComponent("id_ed25519.pub")
        let fm = FileManager.default

        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)

        if !fm.fileExists(atPath: privateKey.path) || !fm.fileExists(atPath: publicKey.path) {
            try await Shell.run([
                "/usr/bin/ssh-keygen",
                "-q",
                "-t", "ed25519",
                "-N", "",
                "-C", "macbox:\(name)",
                "-f", privateKey.path,
            ], quiet: true)
        }

        return ManagedSSHIdentity(
            name: name,
            privateKeyPath: privateKey.path,
            publicKeyPath: publicKey.path
        )
    }

    /// Deletes the managed SSH keypair directory for a distro.
    static func delete(name: String) throws {
        let directory = storageDirectory().appendingPathComponent(name, isDirectory: true)
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
    }

    private static func storageDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("macbox", isDirectory: true)
            .appendingPathComponent("keys", isDirectory: true)
    }
}
