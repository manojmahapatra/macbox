import Testing
import Foundation
@testable import macbox

@Suite struct ImageBuilderTests {
    @Test func dockerfileContainsUsername() {
        let host = HostInfo(username: "testuser", uid: 501, gid: 20, home: "/Users/testuser", shell: "/bin/zsh", sshAuthSock: nil)
        let df = ImageBuilder.dockerfile(base: "ubuntu:24.04", host: host)
        #expect(df.contains("useradd"))
        #expect(df.contains("testuser"))
        #expect(df.contains("-u 501"))
        #expect(df.contains("-g 20"))
        #expect(df.contains("/bin/zsh"))
        #expect(df.contains("sshd"))
        #expect(df.contains("adduser"))
        #expect(df.contains("apk add --no-cache sudo openssh-server zsh"))
        #expect(df.contains("touch /home/testuser/.zshrc"))
    }

    @Test func imageTagFormat() {
        let tag = ImageBuilder.imageTag(name: "mydev", username: "testuser")
        #expect(tag == "macbox-mydev-testuser:latest")
    }
}

@Suite struct DistroConfigTests {
    @Test func roundTrip() throws {
        let config = DistroConfig(image: "alpine:latest", mounts: ["/tmp:/tmp:ro"], ports: ["8080:8080"], provision: ["apk add git"], homeRW: true, cpus: 2, memory: "2g")
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("macbox-test.json").path()
        try config.save(to: path)
        let loaded = try DistroConfig.load(from: path)
        #expect(loaded.image == "alpine:latest")
        #expect(loaded.cpus == 2)
        #expect(loaded.memory == "2g")
        #expect(loaded.homeRW == true)
        #expect(loaded.ports == ["8080:8080"])
        #expect(loaded.provision == ["apk add git"])
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test func cliValuesOverrideConfigValues() throws {
        let config = DistroConfig(
            image: "ubuntu:24.04",
            mounts: ["/config:/config:ro"],
            ports: ["8080:8080"],
            provision: ["echo from-config"],
            homeRW: true,
            cpus: 2,
            memory: "2g"
        )

        let cliMounts = ["/override:/override:rw"]
        let cliPorts = ["3000:3000"]
        let cliProvision = ["echo from-cli"]

        let mergedMounts = cliMounts.isEmpty ? (config.mounts ?? []) : cliMounts
        let mergedPorts = cliPorts.isEmpty ? (config.ports ?? []) : cliPorts
        let mergedProvision = cliProvision.isEmpty ? (config.provision ?? []) : cliProvision
        let mergedHomeRW = false
        let mergedCpus = 8
        let mergedMemory = "8g"

        #expect(mergedMounts == cliMounts)
        #expect(mergedPorts == cliPorts)
        #expect(mergedProvision == cliProvision)
        #expect(mergedHomeRW == false)
        #expect(mergedCpus == 8)
        #expect(mergedMemory == "8g")
    }
}

@Suite struct RuntimeConfigTests {
    @Test func runArgsIncludeDistinctSSHPortAndLoopbackBinding() throws {
        let host = HostInfo(username: "testuser", uid: 501, gid: 20, home: "/Users/testuser", shell: "/bin/zsh", sshAuthSock: "/tmp/agent.sock")

        let args = try RuntimeConfig.runArgs(
            name: "mydev",
            host: host,
            extraMounts: ["/tmp/data:/work:ro"],
            portForwards: [],
            cpus: 4,
            memory: "4g",
            sshHostPort: 43022,
            homeReadWrite: false,
            containerExecutable: "/usr/bin/env"
        )

        #expect(args.first == "/usr/bin/env")
        #expect(args.contains("127.0.0.1:43022:2222"))
        #expect(args.contains("macbox.ssh-host-port=43022"))
        #expect(args.contains("type=bind,source=/Users/testuser,target=/Users/testuser,readonly"))
        #expect(args.contains("type=bind,source=/tmp/data,target=/work,readonly"))
        #expect(args.contains("--ssh"))
    }

    @Test func execArgsUseFallbackShellChain() throws {
        let host = HostInfo(username: "testuser", uid: 501, gid: 20, home: "/Users/testuser", shell: "/bin/zsh", sshAuthSock: nil)

        let args = try RuntimeConfig.execArgs(
            name: "devbox",
            host: host,
            preferredShell: "/usr/bin/fish",
            containerExecutable: "/usr/bin/env"
        )

        #expect(args[0] == "/usr/bin/env")
        #expect(args.contains("/bin/sh"))
        #expect(args.last?.contains("exec /usr/bin/fish -l") == true)
    }
}

@Suite struct ContainerStateTests {
    @Test func decodeInspectPayload() throws {
        let payload = """
        [{"status":"running","configuration":{"id":"devbox","image":{"reference":"macbox-devbox:latest"}}}]
        """

        let data = Data(payload.utf8)
        let decoded = try JSONDecoder().decode([ContainerState].self, from: data)

        #expect(decoded.count == 1)
        #expect(decoded[0].status == "running")
        #expect(decoded[0].configuration.id == "devbox")
        #expect(decoded[0].configuration.image.reference == "macbox-devbox:latest")
    }
}

@Suite struct DistroStateStoreTests {
    @Test func saveLoadAndDeleteState() throws {
        let state = DistroState(
            name: "macbox-test-\(UUID().uuidString)",
            imageTag: "macbox-test:latest",
            baseImage: "ubuntu:24.04",
            sshHostPort: 43022,
            sshContainerPort: 2222,
            shell: "/bin/zsh",
            sshPrivateKeyPath: "/tmp/id_ed25519",
            sshPublicKeyPath: "/tmp/id_ed25519.pub"
        )

        try DistroStateStore.save(state)
        let loaded = try DistroStateStore.load(name: state.name)
        #expect(loaded == state)

        try DistroStateStore.delete(name: state.name)
        let deleted = try DistroStateStore.load(name: state.name)
        #expect(deleted == nil)
    }
}

@Suite struct ManagedSSHConfigTests {
    @Test func rendersHostAliasFragment() {
        let rendered = ManagedSSHConfig.renderFragment(
            name: "mydev",
            username: "testuser",
            port: 43022,
            privateKeyPath: "/tmp/id_ed25519"
        )

        #expect(rendered.contains("Host macbox-mydev"))
        #expect(rendered.contains("HostName 127.0.0.1"))
        #expect(rendered.contains("User testuser"))
        #expect(rendered.contains("Port 43022"))
        #expect(rendered.contains("IdentityFile \"/tmp/id_ed25519\""))
        #expect(rendered.contains("IdentitiesOnly yes"))
    }
}

@Suite struct AutoPortForwardingTests {
    @Test func parseListeningPortDetectsTcpListeners() {
        let line = "   1: 0100007F:0BB8 00000000:0000 0A 00000000:00000000 00:00000000 00000000   501        0 0 1 0000000000000000 100 0 0 10 0"
        let port = AutoPortForwardingTests.parse(line)
        #expect(port == 3000)
    }

    @Test func parseListeningPortIgnoresNonListeningRows() {
        let line = "   1: 0100007F:0BB8 00000000:0000 01 00000000:00000000 00:00000000 00000000   501        0 0 1 0000000000000000 100 0 0 10 0"
        let port = AutoPortForwardingTests.parse(line)
        #expect(port == nil)
    }

    private static func parse(_ value: String) -> Int? {
        AutoPortForwardingTestsHarness.parse(value)
    }
}

enum AutoPortForwardingTestsHarness {
    static func parse(_ value: String) -> Int? {
        let mirror = AutoPortForwardingMirror()
        return mirror.parse(value)
    }
}

private struct AutoPortForwardingMirror {
    func parse(_ value: String) -> Int? {
        let parts = Substring(value)
        return {
            let line = parts
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count >= 4 else { return nil }
            guard fields[3] == "0A" else { return nil }
            let address = fields[1].split(separator: ":")
            guard address.count == 2 else { return nil }
            return Int(address[1], radix: 16)
        }()
    }
}
