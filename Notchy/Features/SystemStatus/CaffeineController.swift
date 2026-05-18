import Foundation

/// Spawns and tracks a `caffeinate` subprocess to prevent the Mac from
/// sleeping. Flags used:
///   -d  prevent display sleep
///   -i  prevent system idle sleep
///   -m  prevent disk sleep
@MainActor
final class CaffeineController {

    private let status: SystemStatusFeature
    private var process: Process?

    init(status: SystemStatusFeature) {
        self.status = status
    }

    /// Start blocking sleep. Idempotent.
    func start() {
        guard process == nil else { return }
        let p = Process()
        p.launchPath = "/usr/bin/caffeinate"
        p.arguments = ["-d", "-i", "-m"]
        do {
            try p.run()
            process = p
            status.isCaffeinated = true
        } catch {
            status.isCaffeinated = false
        }
    }

    /// Stop blocking sleep. Idempotent.
    func stop() {
        process?.terminate()
        process?.waitUntilExit()
        process = nil
        status.isCaffeinated = false
    }

    func toggle() {
        if status.isCaffeinated { stop() } else { start() }
    }
}
