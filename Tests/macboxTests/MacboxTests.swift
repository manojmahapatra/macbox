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
}
