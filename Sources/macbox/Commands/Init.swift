import ArgumentParser
import Foundation

/// Writes a sample `macbox.json` configuration file.
struct Init: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate a sample macbox.json config file."
    )

    @Option(name: .shortAndLong, help: "Output path")
    var output: String = "macbox.json"

    /// Saves the built-in example configuration to disk.
    func run() async throws {
        try DistroConfig.example.save(to: output)
        print("📄 Sample config written to \(output)")
    }
}
