import ArgumentParser

@main
struct Macbox: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Persistent Linux dev environments on macOS via Apple container.",
        subcommands: [Create.self, Enter.self, List.self, Remove.self, Stop.self]
    )
}
