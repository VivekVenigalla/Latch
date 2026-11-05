import AppKit
import LatchCore
import SwiftUI

/// Icons for the task's assigned apps and sites, plus `+ [⌘D]` to assign where you are.
/// Right-click an icon to remove it.
struct WorkspaceStrip: View {
    @EnvironmentObject private var engine: LatchEngine
    let workspace: Workspace
    static let visibleItems = 3

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(workspace.items.prefix(Self.visibleItems)), id: \.self) { item in
                WorkspaceItemIcon(item: item)
                    .contextMenu {
                        Button("Remove from Task") { engine.removeFromWorkspace(item) }
                    }
            }
            if workspace.items.count > Self.visibleItems {
                Text("+\(workspace.items.count - Self.visibleItems)")
                    .font(LatchFont.keycap)
                    .foregroundStyle(Tokens.keycapText)
                    .help(workspace.items.dropFirst(Self.visibleItems).map(WorkspaceItemIcon.name).joined(separator: ", "))
            }
            Button { engine.assignCurrentTarget() } label: { KeycapBadge("+⌘D") }
                .buttonStyle(.plain)
                .keyboardShortcut("d", modifiers: .command)
                .help(assignHelp)
        }
        .animation(Tokens.snap, value: workspace)
    }

    private var assignHelp: String {
        guard let target = engine.driftTarget ?? engine.focusTarget else { return "Assign the current app to this task" }
        return "Assign \(target.displayName) to this task"
    }
}

/// A 14pt app icon, or a globe for a site, with the name as a tooltip.
struct WorkspaceItemIcon: View {
    let item: WorkspaceItem

    var body: some View {
        Group {
            if case let .app(id) = item, let icon = Self.appIcon(id) {
                Image(nsImage: icon).resizable().interpolation(.high)
            } else {
                Image(systemName: "globe")
                    .resizable()
                    .foregroundStyle(Tokens.silver)
                    .padding(1.5)
            }
        }
        .frame(width: 14, height: 14)
        .help(Self.name(item) + " — right-click to remove")
    }

    static func name(_ item: WorkspaceItem) -> String {
        switch item {
        case let .app(id):
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return id }
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        case .site:
            return item.host ?? "Site"
        }
    }

    static func appIcon(_ bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

/// `OFF TASK · Chrome · youtube.com   Assign [⌘D]` — shown while drifting.
struct DriftBanner: View {
    @EnvironmentObject private var engine: LatchEngine
    let target: FocusTarget

    var body: some View {
        HStack(spacing: 6) {
            Rectangle().fill(Tokens.amber).frame(width: 2, height: 10)
            Text("OFF TASK · \(target.displayName)")
                .font(LatchFont.label)
                .kerning(0.6)
                .foregroundStyle(Tokens.amber)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            Button { engine.assignCurrentTarget() } label: {
                HStack(spacing: 4) {
                    Text("Assign")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Tokens.crispWhite)
                    KeycapBadge("⌘D")
                }
            }
            .buttonStyle(.plain)
            .help("Make \(target.displayName) part of this task; this excursion won't count")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(Tokens.amber.opacity(0.08))
        .overlay(alignment: .bottom) { Rectangle().fill(Tokens.amber.opacity(0.25)).frame(height: 1) }
    }
}
