import Foundation

/// Thin wrapper around Process for running shell commands.
enum Shell {

    @discardableResult
    static func run(_ args: String..., quiet: Bool = false) async throws -> String {
        try await run(args, quiet: quiet)
    }

    @discardableResult
    static func run(_ args: [String], quiet: Bool = false) async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        process.standardOutput = quiet ? pipe : FileHandle.standardOutput
        process.standardError = quiet ? pipe : FileHandle.standardError
        if quiet { process.standardOutput = pipe }

        try process.run()
        process.waitUntilExit()

        let data = quiet ? pipe.fileHandleForReading.readDataToEndOfFile() : Data()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            throw MacboxError.commandFailed(args.joined(separator: " "), process.terminationStatus)
        }
        return output
    }

    /// Run interactively (inherits stdin/stdout/stderr).
    static func exec(_ args: [String]) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw MacboxError.commandFailed(args.joined(separator: " "), process.terminationStatus)
        }
    }
}

enum MacboxError: Error, CustomStringConvertible {
    case commandFailed(String, Int32)
    case distroNotFound(String)

    var description: String {
        switch self {
        case .commandFailed(let cmd, let code): "Command failed (\(code)): \(cmd)"
        case .distroNotFound(let name): "Distro '\(name)' not found"
        }
    }
}
