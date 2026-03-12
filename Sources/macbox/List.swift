import ArgumentParser
import Foundation

struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List macbox distros."
    )

    func run() async throws {
        let states = DistroStateStore.all().sorted { $0.name < $1.name }
        guard !states.isEmpty else {
            print("No macbox distros found.")
            return
        }

        let rows = try await states.mapAsync { state in
            let forwarded = (try? AutoPortForwardStore.load(name: state.name))?.forwards ?? []
            let ports = forwarded
                .sorted { $0.hostPort < $1.hostPort }
                .map { "\($0.hostPort)->\($0.containerPort)" }
                .joined(separator: ",")
            do {
                let container = try await ContainerStateReader.inspect(name: state.name)
                return [
                    state.name,
                    container.status,
                    container.configuration.image.reference,
                    "\(state.sshHostPort)",
                    ports,
                ]
            } catch {
                return [state.name, "missing", state.baseImage, "\(state.sshHostPort)", ports]
            }
        }

        print(renderTable(header: ["NAME", "STATUS", "IMAGE", "SSH", "PORTS"], rows: rows))
    }

    private func renderTable(header: [String], rows: [[String]]) -> String {
        let allRows = [header] + rows
        let widths = header.indices.map { column in
            allRows.map { row in row[column].count }.max() ?? 0
        }

        return allRows
            .map { row in
                row.enumerated()
                    .map { index, value in
                        value.padding(toLength: widths[index], withPad: " ", startingAt: 0)
                    }
                    .joined(separator: "  ")
                    .trimmingCharacters(in: .whitespaces)
            }
            .joined(separator: "\n")
    }
}

private extension Array {
    func mapAsync<T>(_ transform: (Element) async throws -> T) async throws -> [T] {
        var results: [T] = []
        results.reserveCapacity(count)
        for element in self {
            results.append(try await transform(element))
        }
        return results
    }
}
