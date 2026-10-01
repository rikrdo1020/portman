import Foundation

struct ContainerInfo: Identifiable {
    var id: String          // short 12-char ID
    var name: String
    var state: String       // running / exited / paused …
    var ports: String       // raw ports string
    var cpuPercent: Double
    var memoryMB: Double
}

enum DockerError: Error {
    case noCLI
    case daemonDown
    case parseError(String)
}

final class DockerClient {
    private let dockerPath: String

    init?() {
        guard let p = resolvedDockerPath() else { return nil }
        dockerPath = p
    }

    // MARK: - Container list

    func listContainers(all: Bool = false) throws -> [ContainerInfo] {
        var args = ["ps", "--format", "{{.ID}}|||{{.Names}}|||{{.State}}|||{{.Ports}}"]
        if all { args.append("--all") }

        let raw: String
        do {
            raw = try shell(dockerPath, args, timeout: 8)
        } catch ShellError.launchFailed(let msg) {
            if msg.contains("Cannot connect") || msg.contains("daemon") {
                throw DockerError.daemonDown
            }
            throw DockerError.parseError(msg)
        }

        return raw.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line -> ContainerInfo? in
                let parts = line.components(separatedBy: "|||")
                guard parts.count >= 4 else { return nil }
                return ContainerInfo(
                    id: parts[0].trimmingCharacters(in: .whitespaces),
                    name: parts[1].trimmingCharacters(in: .whitespaces),
                    state: parts[2].trimmingCharacters(in: .whitespaces),
                    ports: parts[3].trimmingCharacters(in: .whitespaces),
                    cpuPercent: 0,
                    memoryMB: 0
                )
            }
    }

    // MARK: - Stats (slow, ~1s)

    func fetchStats(for ids: [String]) throws -> [String: (cpu: Double, memMB: Double)] {
        guard !ids.isEmpty else { return [:] }
        let args = ["stats", "--no-stream", "--format",
                    "{{.ID}}|||{{.CPUPerc}}|||{{.MemUsage}}"] + ids
        let raw: String
        do {
            raw = try shell(dockerPath, args, timeout: 15)
        } catch ShellError.launchFailed(let msg) {
            if msg.contains("Cannot connect") || msg.contains("daemon") {
                throw DockerError.daemonDown
            }
            return [:]
        }

        var result: [String: (Double, Double)] = [:]
        for line in raw.components(separatedBy: "\n").filter({ !$0.isEmpty }) {
            let parts = line.components(separatedBy: "|||")
            guard parts.count >= 3 else { continue }
            let id = parts[0].trimmingCharacters(in: .whitespaces)
            let cpuStr = parts[1].trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "%", with: "")
            let memParts = parts[2].components(separatedBy: "/")
            let cpu = Double(cpuStr) ?? 0
            let memMB = parseMemoryMB(memParts[0].trimmingCharacters(in: .whitespaces))
            result[id] = (cpu, memMB)
        }
        return result
    }

    // MARK: - Actions

    func stop(containerId: String) {
        _ = try? shell(dockerPath, ["stop", containerId], timeout: 15)
    }

    func stopAll(ids: [String]) {
        for id in ids { stop(containerId: id) }
    }

    // MARK: - Helpers

    private func parseMemoryMB(_ s: String) -> Double {
        // Formats: "1.2GiB", "512MiB", "128KiB", "300MB"
        let lower = s.lowercased()
        if lower.hasSuffix("gib") || lower.hasSuffix("gb") {
            let v = Double(s.dropLast(lower.hasSuffix("gib") ? 3 : 2)) ?? 0
            return v * 1024
        } else if lower.hasSuffix("mib") || lower.hasSuffix("mb") {
            return Double(s.dropLast(lower.hasSuffix("mib") ? 3 : 2)) ?? 0
        } else if lower.hasSuffix("kib") || lower.hasSuffix("kb") {
            let v = Double(s.dropLast(lower.hasSuffix("kib") ? 3 : 2)) ?? 0
            return v / 1024
        }
        return Double(s) ?? 0
    }
}
