import Foundation

/// Records a single host-to-distro TCP forward managed by `macbox`.
struct ForwardedPort: Codable, Sendable, Equatable {
    let containerPort: Int
    let hostPort: Int
    let pid: Int32
}

/// Persisted auto-forwarding state for a distro, including the monitor process.
struct AutoPortForwardState: Codable, Sendable, Equatable {
    let name: String
    var monitorPID: Int32?
    var forwards: [ForwardedPort]
}

/// Stores per-distro port-forward metadata under Application Support.
enum AutoPortForwardStore {
    /// Loads previously saved port-forward state for a distro.
    static func load(name: String) throws -> AutoPortForwardState? {
        let url = stateURL(for: name)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AutoPortForwardState.self, from: data)
    }

    /// Saves the current port-forward state for a distro.
    static func save(_ state: AutoPortForwardState) throws {
        let fm = FileManager.default
        let directory = storageDirectory()
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: stateURL(for: state.name), options: .atomic)
    }

    /// Removes saved port-forward state for a distro.
    static func delete(name: String) throws {
        let url = stateURL(for: name)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    /// Returns all saved port-forward states.
    static func all() -> [AutoPortForwardState] {
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
            return try? JSONDecoder().decode(AutoPortForwardState.self, from: data)
        }
    }

    private static func storageDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("macbox", isDirectory: true)
            .appendingPathComponent("ports", isDirectory: true)
    }

    private static func stateURL(for name: String) -> URL {
        storageDirectory().appendingPathComponent("\(name).json")
    }
}
