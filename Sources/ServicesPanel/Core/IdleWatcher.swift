import Foundation

/// Tracks last-active time per pid and marks services as idle-burning.
final class IdleWatcher {
    // pid → last Date we saw an ESTABLISHED connection
    private var lastActive: [Int32: Date] = [:]

    func update(activePIDs: Set<Int32>, allPIDs: Set<Int32>) {
        let now = Date()
        for pid in activePIDs {
            lastActive[pid] = now
        }
        // seed first-seen so we don't immediately flag brand-new services
        for pid in allPIDs where lastActive[pid] == nil {
            lastActive[pid] = now
        }
        // prune dead pids
        let gone = Set(lastActive.keys).subtracting(allPIDs)
        gone.forEach { lastActive.removeValue(forKey: $0) }
    }

    /// Returns idle minutes for a pid, or nil if it has been active recently.
    func idleMinutes(for pid: Int32) -> Int? {
        guard let last = lastActive[pid] else { return nil }
        let elapsed = Int(Date().timeIntervalSince(last) / 60)
        return elapsed > 0 ? elapsed : nil
    }

    func reset(pid: Int32) {
        lastActive[pid] = Date()
    }
}
