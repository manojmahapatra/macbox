import ArgumentParser
import Foundation

enum ContainerCLI {
    private static let envKey = "MACBOX_CONTAINER_BIN"

    static func command(_ args: String...) throws -> [String] {
        try command(args)
    }

    static func command(_ args: [String], executable explicitExecutable: String? = nil) throws -> [String] {
        [try executable(explicit: explicitExecutable)] + args
    }

    static func executable() throws -> String {
        try executable(explicit: nil)
    }

    private static func executable(explicit explicitExecutable: String?) throws -> String {
        if let explicitExecutable, !explicitExecutable.isEmpty {
            return explicitExecutable
        }

        if let override = ProcessInfo.processInfo.environment[envKey], !override.isEmpty {
            return override
        }

        if let resolved = resolveInPath(command: "container") {
            return resolved
        }

        throw ValidationError(
            """
            Apple container CLI not found.
            Install it from https://github.com/apple/container/releases, start it with `container system start`, or set \(envKey) to the CLI path.
            """
        )
    }

    static func isAvailable() -> Bool {
        (try? executable()) != nil
    }

    private static func resolveInPath(command: String) -> String? {
        let fm = FileManager.default

        if command.contains("/") {
            return fm.isExecutableFile(atPath: command) ? command : nil
        }

        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in path.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory))
                .appendingPathComponent(command)
                .path
            if fm.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        return nil
    }
}
