import SwiftUI
import UserNotifications

@MainActor
final class ServicesStore: ObservableObject {
    @Published var portServices: [Service] = []
    @Published var containerServices: [Service] = []
    @Published var nonDevServices: [Service] = []
    @Published var dockerDaemonDown = false
    @Published var hasIdleBurning = false
    @Published var totalDevCPU: Double = 0

    private var pollTimer: Timer?
    private var dockerTimer: Timer?
    private let idleWatcher = IdleWatcher()
    private let docker = DockerClient()
    private var processSamples: [Int32: ProcessSample] = [:]
    private var cwdCache: [Int32: String] = [:]
    private let prefs = Preferences.load()

    // Panel open state — controls poll frequency
    var isPanelOpen = false {
        didSet { restartPollTimer() }
    }

    // MARK: - Start / Stop

    func start() {
        restartPollTimer()
        startDockerTimer()
        listenForScreenLock()
        requestNotificationPermission()
    }

    func stop() {
        pollTimer?.invalidate()
        dockerTimer?.invalidate()
    }

    // MARK: - Poll loop

    private func restartPollTimer() {
        pollTimer?.invalidate()
        let interval: TimeInterval = isPanelOpen ? 3 : 15
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.pollPorts() }
        }
        // Fire immediately
        Task { await pollPorts() }
    }

    private func startDockerTimer() {
        dockerTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { await self?.pollDocker() }
        }
        Task { await pollDocker() }
    }

    // MARK: - Port scanning

    private func pollPorts() async {
        let rawPorts = await Task.detached(priority: .utility) {
            scanListeningPorts()
        }.value

        let samples = await Task.detached(priority: .utility) {
            sampleAllProcesses()
        }.value

        let activePIDs = await Task.detached(priority: .utility) {
            pidsWithEstablishedConnections()
        }.value

        // Dedupe by (pid, port)
        var seen = Set<String>()
        var devServices: [Service] = []
        var nonDev: [Service] = []

        for raw in rawPorts {
            let key = "\(raw.pid):\(raw.port)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            let isDev = isDevService(command: raw.command, port: raw.port,
                                     portRangeMin: prefs.portRangeMin,
                                     portRangeMax: prefs.portRangeMax)

            let pgid = samples[raw.pid]?.pgid ?? raw.pid
            let metrics = metricsForPGID(pgid, in: samples)

            // CWD — cached per pid
            var cwd = cwdCache[raw.pid] ?? ""
            if cwd.isEmpty {
                cwd = await Task.detached(priority: .utility) {
                    cwdForPID(raw.pid)
                }.value
                cwdCache[raw.pid] = cwd
            }

            let projectName = cwd.isEmpty ? "" : URL(fileURLWithPath: cwd).lastPathComponent
            let id = "port:\(raw.port)"

            // Find existing service to preserve firstSeen / lastActiveAt
            let existing = portServices.first { $0.id == id }
            let idleWatcherValue = idleWatcher  // capture for use below

            let health: HealthState
            if metrics.cpuPercent > 25 {
                health = .hotCPU
            } else if let idleMin = idleWatcherValue.idleMinutes(for: raw.pid),
                      idleMin >= prefs.idleMinutesThreshold,
                      metrics.cpuPercent >= prefs.idleCPUThreshold {
                health = .idleBurning(minutes: idleMin)
            } else {
                health = .normal
            }

            let svc = Service(
                id: id,
                kind: .port(number: raw.port),
                command: raw.command,
                projectName: projectName,
                cwd: cwd,
                pid: raw.pid,
                pgid: pgid,
                metrics: metrics,
                health: health,
                isDevService: isDev,
                firstSeen: existing?.firstSeen ?? Date(),
                lastActiveAt: activePIDs.contains(raw.pid) ? Date() : (existing?.lastActiveAt ?? Date())
            )

            if isDev { devServices.append(svc) } else { nonDev.append(svc) }
        }

        let allPIDs = Set(rawPorts.map { $0.pid })
        idleWatcher.update(activePIDs: activePIDs, allPIDs: allPIDs)

        portServices = devServices.sorted { $0.port ?? 0 < $1.port ?? 0 }
        nonDevServices = nonDev.sorted { $0.port ?? 0 < $1.port ?? 0 }
        processSamples = samples

        recomputeSummary()
    }

    // MARK: - Docker

    private func pollDocker() async {
        guard let docker = docker else { return }
        do {
            var containers = try docker.listContainers()
            let runningIDs = containers.filter { $0.state == "running" }.map { $0.id }

            if !runningIDs.isEmpty {
                let stats = (try? docker.fetchStats(for: runningIDs)) ?? [:]
                for i in containers.indices {
                    if let s = stats[containers[i].id] {
                        containers[i].cpuPercent = s.cpu
                        containers[i].memoryMB = s.memMB
                    }
                }
            }

            dockerDaemonDown = false
            containerServices = containers.map { c in
                let health: HealthState = c.cpuPercent > 25 ? .hotCPU : .normal
                return Service(
                    id: "container:\(c.id)",
                    kind: .container(id: c.id),
                    command: c.name,
                    projectName: c.name,
                    cwd: "",
                    pid: 0,
                    pgid: 0,
                    metrics: Metrics(cpuPercent: c.cpuPercent, memoryMB: c.memoryMB),
                    health: health,
                    isDevService: true,
                    firstSeen: Date(),
                    lastActiveAt: Date()
                )
            }
        } catch DockerError.daemonDown {
            dockerDaemonDown = true
            containerServices = []
        } catch {
            // parse error — keep last known state
        }

        recomputeSummary()
    }

    private func recomputeSummary() {
        let allDev = portServices + containerServices
        totalDevCPU = allDev.reduce(0) { $0 + $1.metrics.cpuPercent }
        hasIdleBurning = allDev.contains { if case .idleBurning = $0.health { return true }; return false }

        // Notify for newly-idle services
        for svc in portServices {
            if case .idleBurning(let min) = svc.health, min == prefs.idleMinutesThreshold {
                sendIdleNotification(for: svc)
            }
        }
    }

    // MARK: - Kill actions

    func killService(_ svc: Service) {
        switch svc.kind {
        case .port:
            guard svc.pgid > 0 else { break }
            killProcessGroup(svc.pgid)
            cwdCache.removeValue(forKey: svc.pid)
        case .container(let id):
            docker?.stop(containerId: id)
        }
        // Optimistic removal
        portServices.removeAll { $0.id == svc.id }
        containerServices.removeAll { $0.id == svc.id }
    }

    func killAllDev(confirm: Bool = true) {
        let allDev = portServices + containerServices
        guard !allDev.isEmpty else { return }

        for svc in allDev { killService(svc) }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendIdleNotification(for svc: Service) {
        let content = UNMutableNotificationContent()
        content.title = "Idle service burning CPU"
        content.body = "\(svc.displayName) on :\(svc.port ?? 0) has been idle for \(prefs.idleMinutesThreshold) min but is still using CPU."
        content.sound = .default
        let req = UNNotificationRequest(identifier: "idle-\(svc.id)",
                                        content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    // MARK: - Screen lock

    private func listenForScreenLock() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.pollTimer?.invalidate()
                    self?.dockerTimer?.invalidate()
                }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.restartPollTimer()
                    self?.startDockerTimer()
                }
        }
    }
}
