import AppKit
import LatchCore
import SwiftUI

/// Switches between the four FSM states. Exactly one task is ever on screen.
struct RootPopoverView: View {
    @EnvironmentObject private var engine: LatchEngine

    var body: some View {
        ZStack(alignment: .top) {
            switch engine.state {
            case .permissionsRequired:
                PermissionsView()
                    .transition(.opacity)
            case let .unlatchedSelector(candidate, filterMode):
                UnlatchedCardView(candidate: candidate, filterMode: filterMode)
                    .transition(.opacity)
            case let .latchedFocus(session):
                LatchedFocusView(session: session)
                    .transition(.opacity)
            case let .stateDumpGate(session):
                StateDumpGateView(session: session)
                    .transition(.opacity)
            }
        }
        .frame(width: Tokens.popoverWidth)
        .frame(minHeight: Tokens.popoverMinHeight, maxHeight: Tokens.popoverMaxHeight, alignment: .top)
        .clipped()
        .background {
            ZStack {
                VisualEffectBackground()
                Tokens.obsidian.opacity(0.65)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.windowCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.windowCornerRadius, style: .continuous)
                .strokeBorder(Tokens.perimeter, lineWidth: 1)
        }
        .environment(\.colorScheme, .dark)
        .animation(Tokens.snap, value: engine.state.phase)
        .background(WindowKeyObserver { engine.popoverDidOpen() })
    }
}

// MARK: - Permissions

private struct PermissionsView: View {
    @EnvironmentObject private var engine: LatchEngine

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                PopoverHeader(label: "LATCH · SETUP")
                Text("Reminders access required")
                    .font(LatchFont.title)
                    .tracking(-0.2)
                    .foregroundStyle(Tokens.crispWhite)
                Text(engine.permissionDenied
                     ? "Access was denied. Enable Latch under Privacy & Security → Reminders (and Calendars for meeting-aware clamping)."
                     : "Latch reads one task at a time from Apple Reminders. Calendar access lets sessions stop before meetings.")
                    .font(LatchFont.meta)
                    .foregroundStyle(Tokens.silver)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)

            Spacer(minLength: 0)
            Hairline()

            HStack(spacing: 6) {
                if engine.permissionDenied {
                    KeycapButton(title: "Open Settings", key: "↩", prominent: true) {
                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")!
                        NSWorkspace.shared.open(url)
                    }
                    .keyboardShortcut(.return, modifiers: [])
                } else {
                    KeycapButton(title: "Grant Access", key: "↩", prominent: true) {
                        Task { await engine.requestPermissions() }
                    }
                    .keyboardShortcut(.return, modifiers: [])
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Shared header

struct PopoverHeader: View {
    let label: String
    var labelColor: Color = Tokens.silver
    var glyph: DeadboltLayout?

    var body: some View {
        HStack(spacing: 8) {
            if let glyph {
                DeadboltGlyphView(layout: glyph, scale: 0.85)
            }
            SectionLabel(label, color: labelColor)
            Spacer()
            Button { NSApp.terminate(nil) } label: { KeycapBadge("⌘Q") }
                .buttonStyle(.plain)
                .keyboardShortcut("q", modifiers: .command)
                .help("Quit Latch")
        }
    }
}

// MARK: - Window chrome

/// Behind-window blur for the popover panel, the AppKit counterpart of `.ultraThinMaterial`.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

// MARK: - Window observation

/// Fires `onBecomeKey` each time the hosting window (the MenuBarExtra panel) becomes key,
/// i.e. each time the user opens the popover.
struct WindowKeyObserver: NSViewRepresentable {
    let onBecomeKey: () -> Void

    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onBecomeKey = onBecomeKey
        return view
    }

    func updateNSView(_ view: ObserverView, context: Context) {
        view.onBecomeKey = onBecomeKey
    }

    final class ObserverView: NSView {
        var onBecomeKey: (() -> Void)?
        private var token: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let token { NotificationCenter.default.removeObserver(token) }
            token = nil
            guard let window else { return }
            token = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
            ) { [weak self] _ in
                self?.onBecomeKey?()
            }
            if window.isKeyWindow {
                DispatchQueue.main.async { [weak self] in self?.onBecomeKey?() }
            }
        }

        deinit {
            if let token { NotificationCenter.default.removeObserver(token) }
        }
    }
}

/// Turns scroll-wheel ticks and horizontal drags into ±1 steps (used by the duration dial).
/// Dragging left pulls higher values under the index, like sliding a physical ruler.
struct DialInputCatcher: NSViewRepresentable {
    var pointsPerStep: CGFloat
    let onStep: (Int) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onStep = onStep
        view.pointsPerStep = pointsPerStep
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.onStep = onStep
        view.pointsPerStep = pointsPerStep
    }

    final class CatcherView: NSView {
        var onStep: ((Int) -> Void)?
        var pointsPerStep: CGFloat = 8
        private var accumulator: CGFloat = 0
        private let threshold: CGFloat = 14
        private var dragStartX: CGFloat?
        private var dragAppliedSteps = 0

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .resizeLeftRight)
        }

        override func mouseDown(with event: NSEvent) {
            dragStartX = convert(event.locationInWindow, from: nil).x
            dragAppliedSteps = 0
        }

        override func mouseDragged(with event: NSEvent) {
            guard let dragStartX else { return }
            let dx = convert(event.locationInWindow, from: nil).x - dragStartX
            let target = Int((-dx / pointsPerStep).rounded())
            if target != dragAppliedSteps {
                onStep?(target - dragAppliedSteps)
                dragAppliedSteps = target
            }
        }

        override func mouseUp(with event: NSEvent) {
            dragStartX = nil
        }

        override func scrollWheel(with event: NSEvent) {
            accumulator += event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 1 : 10)
            while abs(accumulator) >= threshold {
                let step = accumulator > 0 ? 1 : -1
                onStep?(step)
                accumulator -= CGFloat(step) * threshold
            }
            if event.phase == .ended || event.momentumPhase == .ended { accumulator = 0 }
        }
    }
}
