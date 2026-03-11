import ArgumentParser

struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List macbox distros."
    )

    func run() async throws {
        try await Shell.run(
            "container", "ps", "-a",
            "--filter", "label=macbox",
            "--format", "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}"
        )
    }
}
