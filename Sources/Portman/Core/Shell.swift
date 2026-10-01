import Foundation

enum ShellError: Error {
    case launchFailed(String)
    case timeout
}

/// Run a command with explicit binary path (menu bar apps don't inherit shell PATH).
/// Returns stdout string, throws on non-zero exit or timeout.
@discardableResult
func shell(_ binary: String, _ args: [String], timeout: TimeInterval = 10) throws -> String {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: binary)
    proc.arguments = args

    let outPipe = Pipe()
    let errPipe = Pipe()
    proc.standardOutput = outPipe
    proc.standardError = errPipe

    do {
        try proc.run()
    } catch {
        throw ShellError.launchFailed("Cannot launch \(binary): \(error)")
    }

    // Wait with timeout via DispatchSemaphore
    let sem = DispatchSemaphore(value: 0)
    proc.terminationHandler = { _ in sem.signal() }
    let result = sem.wait(timeout: .now() + timeout)

    if result == .timedOut {
        proc.terminate()
        throw ShellError.timeout
    }

    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    if proc.terminationStatus != 0 {
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let errStr = String(data: errData, encoding: .utf8) ?? ""
        throw ShellError.launchFailed("Exit \(proc.terminationStatus): \(errStr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
    return output
}

/// Non-throwing version — returns nil on failure.
func shellOrNil(_ binary: String, _ args: [String], timeout: TimeInterval = 10) -> String? {
    try? shell(binary, args, timeout: timeout)
}

/// Kill a process group with SIGTERM, then SIGKILL after grace period.
func killProcessGroup(_ pgid: Int32, gracePeriod: TimeInterval = 3) {
    Darwin.killpg(pgid, SIGTERM)
    DispatchQueue.global().asyncAfter(deadline: .now() + gracePeriod) {
        // Check if still alive
        if Darwin.killpg(pgid, 0) == 0 {
            Darwin.killpg(pgid, SIGKILL)
        }
    }
}

/// Candidate paths for docker CLI (never in PATH for .app bundles)
let dockerPaths = [
    "/usr/local/bin/docker",
    "/opt/homebrew/bin/docker",
    "/usr/bin/docker",
    "/Applications/Docker.app/Contents/Resources/bin/docker"
]

func resolvedDockerPath() -> String? {
    dockerPaths.first { FileManager.default.fileExists(atPath: $0) }
}
