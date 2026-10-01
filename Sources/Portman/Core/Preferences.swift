import Foundation

final class Preferences: ObservableObject {
    static let shared = Preferences()

    @Published var portRangeMin: Int
    @Published var portRangeMax: Int
    @Published var idleMinutesThreshold: Int
    @Published var idleCPUThreshold: Double
    @Published var showNonDevPorts: Bool
    @Published var commandDenylist: [String]

    private init() {
        let d = UserDefaults.standard
        portRangeMin         = d.object(forKey: "portRangeMin") as? Int ?? 3000
        portRangeMax         = d.object(forKey: "portRangeMax") as? Int ?? 9999
        idleMinutesThreshold = d.object(forKey: "idleMinutesThreshold") as? Int ?? 20
        idleCPUThreshold     = d.object(forKey: "idleCPUThreshold") as? Double ?? 1.0
        showNonDevPorts      = d.object(forKey: "showNonDevPorts") as? Bool ?? false
        commandDenylist      = d.object(forKey: "commandDenylist") as? [String] ?? []
    }

    func save() {
        let d = UserDefaults.standard
        d.set(portRangeMin,         forKey: "portRangeMin")
        d.set(portRangeMax,         forKey: "portRangeMax")
        d.set(idleMinutesThreshold, forKey: "idleMinutesThreshold")
        d.set(idleCPUThreshold,     forKey: "idleCPUThreshold")
        d.set(showNonDevPorts,      forKey: "showNonDevPorts")
        d.set(commandDenylist,      forKey: "commandDenylist")
    }
}

// Alias used in ServicesStore
extension Preferences {
    static func load() -> Preferences { .shared }
}
