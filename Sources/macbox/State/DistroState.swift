import Foundation

/// Persisted metadata `macbox` needs to reconnect to an existing distro.
struct DistroState: Codable, Sendable, Equatable {
    let name: String
    let imageTag: String
    let baseImage: String
    let sshHostPort: Int
    let sshContainerPort: Int
    let shell: String
    let sshPrivateKeyPath: String?
    let sshPublicKeyPath: String?

    /// Synthesizes state for older distros that predate saved metadata.
    static func legacy(name: String, host: HostInfo) -> DistroState {
        DistroState(
            name: name,
            imageTag: ImageBuilder.imageTag(name: name, username: host.username),
            baseImage: "",
            sshHostPort: ImageBuilder.sshPort,
            sshContainerPort: ImageBuilder.sshPort,
            shell: RuntimeConfig.containerShell(from: host.shell),
            sshPrivateKeyPath: nil,
            sshPublicKeyPath: nil
        )
    }
}

/// Stores per-distro runtime metadata under Application Support.
enum DistroStateStore {
    /// Loads saved state for a distro if present.
    static func load(name: String) throws -> DistroState? {
        let fm = FileManager.default
        let url = stateURL(for: name)
        guard fm.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(DistroState.self, from: data)
    }

    /// Saves distro state atomically.
    static func save(_ state: DistroState) throws {
        let fm = FileManager.default
        let directory = storageDirectory()
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: stateURL(for: state.name), options: .atomic)
    }

    /// Deletes saved state for a distro.
    static func delete(name: String) throws {
        let fm = FileManager.default
        let url = stateURL(for: name)
        guard fm.fileExists(atPath: url.path) else { return }
        try fm.removeItem(at: url)
    }

    /// Returns all saved distro states.
    static func all() -> [DistroState] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: storageDirectory(),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(DistroState.self, from: data)
        }
    }

    private static func storageDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("macbox", isDirectory: true)
            .appendingPathComponent("distros", isDirectory: true)
    }

    private static func stateURL(for name: String) -> URL {
        storageDirectory().appendingPathComponent("\(name).json")
    }
}
