import ArgumentParser

@main
struct Macbox: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Persistent Linux dev environments on macOS via Apple container.",
        subcommands: [Create.self, Enter.self, List.self, Ports.self, Remove.self, Stop.self, Init.self, PortSync.self]
    )
}
