import Foundation

struct ProcessSample {
    var pid: Int32
    var ppid: Int32
    var pgid: Int32
    var cpuPercent: Double
    var rssKB: Int64
}

/// Single `ps` call for all processes, keyed by pid.
func sampleAllProcesses() -> [Int32: ProcessSample] {
    guard let out = shellOrNil("/bin/ps",
        ["-Ao", "pid=,ppid=,pgid=,%cpu=,rss="],
        timeout: 5)
    else { return [:] }

    var map: [Int32: ProcessSample] = [:]
    for line in out.components(separatedBy: "\n") {
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 5,
              let pid  = Int32(parts[0]),
              let ppid = Int32(parts[1]),
              let pgid = Int32(parts[2]),
              let cpu  = Double(parts[3]),
              let rss  = Int64(parts[4])
        else { continue }
        map[pid] = ProcessSample(pid: pid, ppid: ppid, pgid: pgid, cpuPercent: cpu, rssKB: rss)
    }
    return map
}

/// Aggregate CPU + RSS for all processes in the same pgid.
func metricsForPGID(_ pgid: Int32, in samples: [Int32: ProcessSample]) -> Metrics {
    var totalCPU: Double = 0
    var totalRSS: Int64 = 0
    for s in samples.values where s.pgid == pgid {
        totalCPU += s.cpuPercent
        totalRSS += s.rssKB
    }
    return Metrics(cpuPercent: totalCPU, memoryMB: Double(totalRSS) / 1024.0)
}
