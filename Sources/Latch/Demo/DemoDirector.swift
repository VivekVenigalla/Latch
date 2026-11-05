import AppKit
import LatchCore

/// Stages one demo scene, then writes a JSON report (window numbers and the status item's frame,
/// in `screencapture` coordinates) for `scripts/screenshots.sh`.
///
/// Scenes: `menubar`, `selector`, `latched`, `drifting`, `gate`, `capture`, `menu`.
@MainActor
final class DemoDirector {
    private let engine: LatchEngine
    private let statusItem: StatusItemController
    private let capture: BlindCaptureController

    init(engine: LatchEngine, statusItem: StatusItemController, capture: BlindCaptureController) {
        self.engine = engine
        self.statusItem = statusItem
        self.capture = capture
    }

    func run(scene: String) async {
        engine.ledger.save(DayLedger(
            day: DayLedger.dayKey(for: .now), focusedSeconds: 8040, driftSeconds: 482, sessions: 4, completed: 3))
        await engine.bootstrap()

        switch scene {
        case "selector":
            statusItem.openPanel()
        case "latched":
            latchSample()
            statusItem.openPanel()
        case "drifting":
            latchSample()
            let tab = FocusTarget(
                bundleID: "com.apple.Safari", appName: "Safari", isBrowser: true,
                url: URL(string: "https://www.youtube.com/watch?v=demo"))
            engine.focusChanged(to: tab, at: .now.addingTimeInterval(-75))
            statusItem.openPanel()
        case "gate":
            latchSample()
            engine.unlatch()
            statusItem.openPanel()
        case "capture":
            capture.show(prefill: "Email Sam the rollout notes ~10m !high #Work")
        case "menu":
            latchSample()
        default:
            break
        }

        // Let animations and layout settle before anything is measured or captured.
        try? await Task.sleep(for: .milliseconds(1200))
        writeReport(scene: scene)

        // Menu tracking blocks this run loop, so the report has to be written first.
        if scene == "menu" { statusItem.showMenu() }
    }

    /// Latches the top sample task as if it started 7 minutes ago, pinned to Xcode, with two
    /// micro-steps — a session in full swing.
    private func latchSample() {
        guard let candidate = engine.currentCandidate else { return }
        let xcode = PinnedApp(bundleIdentifier: "com.apple.dt.Xcode", name: "Xcode", processIdentifier: 0)
        engine.latch(onto: candidate, pinnedApp: xcode, now: .now.addingTimeInterval(-7 * 60))
        engine.focusChanged(to: FocusTarget(bundleID: "com.apple.dt.Xcode", appName: "Xcode"))
        engine.addMicroStep("Reproduce with an expired token")
        engine.addMicroStep("Guard refresh against clock skew")
        if let first = engine.microSteps.first { engine.toggleMicroStep(first.id) }
    }

    private func writeReport(scene: String) {
        guard let path = DemoMode.reportPath else { return }
        var report: [String: Any] = ["scene": scene]
        if let frame = statusItem.itemFrameOnScreen {
            // screencapture's -R takes points with the origin at the top-left of the main display.
            let mainHeight = NSScreen.screens.first?.frame.height ?? 0
            report["item"] = [frame.minX, mainHeight - frame.maxY, frame.width, frame.height].map { Int($0.rounded()) }
        }
        if let number = statusItem.panelWindowNumber { report["panelWindow"] = number }
        if let number = capture.windowNumber { report["captureWindow"] = number }
        guard let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]) else { return }
        FileManager.default.createFile(atPath: path, contents: data)
    }
}
