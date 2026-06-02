import Foundation

public struct CodexUsageProvider {
    private let sessionsDirectory: URL

    /// Defaults to ~/.codex/sessions
    public init(sessionsDirectory: URL? = nil) {
        if let dir = sessionsDirectory {
            self.sessionsDirectory = dir
        } else {
            self.sessionsDirectory = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".codex/sessions")
        }
    }

    public func snapshot(now: Date) -> UsageSnapshot {
        guard let file = newestRolloutFile(),
              let text = try? String(contentsOf: file, encoding: .utf8) else {
            return .unavailable(.codex, asOf: now)
        }
        let lines = text.split(separator: "\n").map(String.init)
        guard let rl = CodexRateLimits.lastRateLimits(inLines: lines) else {
            return .unavailable(.codex, asOf: now)
        }
        return UsageSnapshot(
            provider: .codex,
            fiveHour: window(rl.primary, now: now),
            weekly: window(rl.secondary, now: now),
            asOf: now,
            status: .ok
        )
    }

    /// If the window already reset (resets_at < now), the percentage is stale → treat as 0.
    private func window(_ w: CodexRateLimits.Window, now: Date) -> WindowUsage {
        if let reset = w.resetsAt, reset < now {
            return WindowUsage(usedPercent: 0, resetsAt: nil)
        }
        return WindowUsage(usedPercent: w.usedPercent, resetsAt: w.resetsAt)
    }

    /// Recursively finds rollout-*.jsonl files; newest by modification time.
    func newestRolloutFile() -> URL? {
        let fm = FileManager.default
        guard let en = fm.enumerator(at: sessionsDirectory,
                                     includingPropertiesForKeys: [.contentModificationDateKey],
                                     options: [.skipsHiddenFiles]) else { return nil }
        var best: (url: URL, mtime: Date)?
        for case let url as URL in en {
            guard url.lastPathComponent.hasPrefix("rollout-"),
                  url.pathExtension == "jsonl" else { continue }
            let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if best == nil || mtime > best!.mtime {
                best = (url, mtime)
            }
        }
        return best?.url
    }
}
