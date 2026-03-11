import ArgumentParser
import Foundation

struct Init: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate a sample macbox.json config file."
    )

    @Option(name: .shortAndLong, help: "Output path")
    var output: String = "macbox.json"

    func run() async throws {
        try DistroConfig.example.save(to: output)
        print("📄 Sample config written to \(output)")
    }
}
