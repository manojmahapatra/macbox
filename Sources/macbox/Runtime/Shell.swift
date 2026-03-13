import Foundation

/// Thin wrapper around Process for running shell commands.
enum Shell {

    /// Runs a command and returns its trimmed stdout.
    @discardableResult
    static func run(_ args: String..., quiet: Bool = false) async throws -> String {
        try await run(args, quiet: quiet)
    }

    /// Runs a command, optionally suppressing streamed output, and returns its trimmed stdout.
    @discardableResult
    static func run(_ args: [String], quiet: Bool = false) async throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        guard let executable = args.first else {
            throw MacboxError.invalidCommand
        }

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(args.dropFirst())
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !quiet {
            if !outputData.isEmpty {
                FileHandle.standardOutput.write(outputData)
            }
            if !errorData.isEmpty {
                FileHandle.standardError.write(errorData)
            }
        }

        guard process.terminationStatus == 0 else {
            throw MacboxError.commandFailed(args.joined(separator: " "), process.terminationStatus, errorOutput.isEmpty ? output : errorOutput)
        }
        return output
    }

    /// Runs a command interactively, inheriting the current terminal streams.
    static func exec(_ args: [String]) async throws {
        let process = Process()
        guard let executable = args.first else {
            throw MacboxError.invalidCommand
        }
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(args.dropFirst())
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw MacboxError.commandFailed(args.joined(separator: " "), process.terminationStatus, "")
        }
    }
}

/// User-facing errors emitted by the CLI.
enum MacboxError: Error, CustomStringConvertible {
    case commandFailed(String, Int32, String)
    case distroNotFound(String)
    case invalidCommand
    case invalidMountSpec(String)
    case portAllocationFailed
    case portForwardFailed(String, Int)

    var description: String {
        switch self {
        case .commandFailed(let cmd, let code, let details):
            if details.isEmpty {
                return "Command failed (\(code)): \(cmd)"
            }
            return "Command failed (\(code)): \(cmd)\n\(details)"
        case .distroNotFound(let name):
            return "Distro '\(name)' not found"
        case .invalidCommand:
            return "Invalid command"
        case .invalidMountSpec(let spec):
            return "Invalid mount spec '\(spec)'. Expected host:guest[:ro]"
        case .portAllocationFailed:
            return "Unable to allocate an available SSH port"
        case .portForwardFailed(let name, let port):
            return "Unable to start port forward for '\(name)' on container port \(port)"
        }
    }
}
