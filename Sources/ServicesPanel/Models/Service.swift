import Foundation

enum ServiceKind: Equatable {
    case port(number: Int)
    case container(id: String)
}

enum HealthState: Equatable {
    case normal
    case idleBurning(minutes: Int)
    case hotCPU          // cpu > 25%
}

struct Metrics: Equatable {
    var cpuPercent: Double   // summed over pgid
    var memoryMB: Double
}

struct Service: Identifiable, Equatable {
    let id: String           // "port:3000" or "container:<id>"
    var kind: ServiceKind
    var command: String      // vite, node, python3, …
    var projectName: String  // last path component of cwd
    var cwd: String
    var pid: Int32
    var pgid: Int32
    var metrics: Metrics
    var health: HealthState
    var isDevService: Bool
    var firstSeen: Date
    var lastActiveAt: Date   // last time we saw an ESTABLISHED connection

    // Convenience
    var port: Int? {
        if case .port(let n) = kind { return n }
        return nil
    }

    var containerId: String? {
        if case .container(let id) = kind { return id }
        return nil
    }

    var displayName: String {
        projectName.isEmpty ? command : projectName
    }

    var localhostURL: URL? {
        guard let p = port else { return nil }
        return URL(string: "http://localhost:\(p)")
    }
}
