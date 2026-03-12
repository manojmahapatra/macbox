import Foundation

/// JSON config file for defining a distro. Saved as `macbox.json`.
/// Allows sharing/versioning distro definitions.
struct DistroConfig: Codable, Sendable {
    var image: String
    var mounts: [String]?
    var ports: [String]?
    var provision: [String]?  // Scripts to run after first create
    var homeRW: Bool?
    var cpus: Int?
    var memory: String?       // e.g. "4g", "2048m"

    static func load(from path: String) throws -> DistroConfig {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(DistroConfig.self, from: data)
    }

    func save(to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: URL(fileURLWithPath: path))
    }

    /// Generates a sample config file.
    static let example = DistroConfig(
        image: "ubuntu:24.04",
        mounts: ["~/projects:/home/user/projects:rw"],
        ports: ["3000:3000", "8080:8080"],
        provision: ["apt-get update && apt-get install -y git curl nodejs"],
        homeRW: false,
        cpus: 4,
        memory: "4g"
    )
}
