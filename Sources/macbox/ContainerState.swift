import Foundation

struct ContainerState: Decodable, Sendable {
    struct Configuration: Decodable, Sendable {
        struct Image: Decodable, Sendable {
            let reference: String
        }

        let id: String
        let image: Image
    }

    let status: String
    let configuration: Configuration
}

enum ContainerStateReader {
    static func inspect(name: String) async throws -> ContainerState {
        do {
            let output = try await Shell.run(try ContainerCLI.command("inspect", name), quiet: true)
            let states = try decode(output)
            guard let state = states.first else {
                throw MacboxError.distroNotFound(name)
            }
            return state
        } catch let error as MacboxError {
            throw error
        } catch {
            throw MacboxError.distroNotFound(name)
        }
    }

    private static func decode(_ output: String) throws -> [ContainerState] {
        let data = Data(output.utf8)
        return try JSONDecoder().decode([ContainerState].self, from: data)
    }
}
