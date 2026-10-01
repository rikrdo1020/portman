import Foundation

/// Parses `lsof -nP -iTCP -sTCP:LISTEN -F pcnLR` output.
/// -F format: one field per line, prefixed by letter.
///   p = PID, R = PPID (parent), c = command, L = login user, n = name (host:port or filename)
struct RawPort {
    var pid: Int32
    var ppid: Int32
    var command: String
    var loginUser: String
    var host: String
    var port: Int
}

func scanListeningPorts() -> [RawPort] {
    guard let output = shellOrNil("/usr/sbin/lsof",
        ["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcnLR"],
        timeout: 8)
    else { return [] }

    var results: [RawPort] = []
    var pid: Int32 = 0
    var ppid: Int32 = 0
    var command = ""
    var loginUser = ""

    for line in output.components(separatedBy: "\n") {
        guard !line.isEmpty else { continue }
        let prefix = line.prefix(1)
        let value = String(line.dropFirst())

        switch prefix {
        case "p": pid = Int32(value) ?? 0
        case "R": ppid = Int32(value) ?? 0
        case "c": command = value
        case "L": loginUser = value
        case "n":
            // format: *:PORT or 127.0.0.1:PORT or [::1]:PORT
            if let colon = value.lastIndex(of: ":") {
                let host = String(value[value.startIndex..<colon])
                let portStr = String(value[value.index(after: colon)...])
                if let portNum = Int(portStr), pid > 0 {
                    let raw = RawPort(pid: pid, ppid: ppid, command: command,
                                      loginUser: loginUser, host: host, port: portNum)
                    results.append(raw)
                }
            }
        default: break
        }
    }
    return results
}

// MARK: - CWD enrichment

func cwdForPID(_ pid: Int32) -> String {
    // lsof -p PID -a -d cwd -F n  → lines starting with 'n' are the cwd path
    guard let out = shellOrNil("/usr/sbin/lsof",
        ["-p", "\(pid)", "-a", "-d", "cwd", "-F", "n"],
        timeout: 4)
    else { return "" }

    for line in out.components(separatedBy: "\n") {
        if line.hasPrefix("n") {
            return String(line.dropFirst())
        }
    }
    return ""
}

func commandLineForPID(_ pid: Int32) -> String {
    shellOrNil("/bin/ps", ["-p", "\(pid)", "-o", "args="], timeout: 3)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

// MARK: - Established connections (for idle detection)

func pidsWithEstablishedConnections() -> Set<Int32> {
    guard let out = shellOrNil("/usr/sbin/lsof",
        ["-nP", "-iTCP", "-sTCP:ESTABLISHED", "-F", "p"],
        timeout: 6)
    else { return [] }

    var pids = Set<Int32>()
    for line in out.components(separatedBy: "\n") {
        if line.hasPrefix("p"), let pid = Int32(line.dropFirst()) {
            pids.insert(pid)
        }
    }
    return pids
}

// MARK: - Dev service classifier

private let devPortSet: Set<Int> = [
    1433, 3000, 3001, 3002, 3003, 3306, 4000, 4200, 4567, 5000,
    5001, 5173, 5432, 6379, 8000, 8080, 8081, 8443, 8888, 9000,
    9090, 9200, 9229, 27017
]

private let devCommandPrefixes = [
    "node", "python", "ruby", "java", "dotnet", "php",
    "deno", "bun", "cargo", "go", "uvicorn", "gunicorn",
    "rails", "puma", "flask", "fastapi", "vite", "next",
    "webpack", "parcel", "esbuild"
]

private let systemCommandDenylist = [
    "ControlCenter", "ControlCe", "rapportd", "OneDrive",
    "sharingd", "Microsoft", "Kaspersky", "LM Studio", "LM\\x20Stu",
    "Code\\x20H", "Code Helper"
]

func isDevService(command: String, port: Int, portRangeMin: Int = 3000, portRangeMax: Int = 9999) -> Bool {
    // Block known system processes
    for blocked in systemCommandDenylist {
        if command.lowercased().hasPrefix(blocked.lowercased()) { return false }
    }
    // Named dev ports (db, cache, etc.)
    if devPortSet.contains(port) { return true }
    // Port range
    if port >= portRangeMin && port <= portRangeMax { return true }
    // Command name
    let cmdLower = command.lowercased()
    for prefix in devCommandPrefixes {
        if cmdLower.hasPrefix(prefix) { return true }
    }
    return false
}
