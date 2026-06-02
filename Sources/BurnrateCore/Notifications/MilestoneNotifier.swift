import Foundation

public final class MilestoneNotifier: @unchecked Sendable {
    public static let thresholds: [Int] = [50, 75, 90]

    private let dispatcher: NotificationDispatcher
    public var enabled: Bool = true

    // Per (provider, window) — the highest threshold already fired, and the reset that armed it.
    private struct Key: Hashable { let provider: Provider; let window: WindowKind }
    private enum WindowKind: String { case fiveHour, weekly }
    private struct State { var firedMax: Int; var resetsAt: Date? }
    private var states: [Key: State] = [:]

    public init(dispatcher: NotificationDispatcher) {
        self.dispatcher = dispatcher
    }

    public func evaluate(_ snapshot: UsageSnapshot) {
        guard enabled, snapshot.status == .ok else { return }
        check(provider: snapshot.provider, window: .fiveHour, label: "5-hour",
              usage: snapshot.fiveHour)
        check(provider: snapshot.provider, window: .weekly, label: "weekly",
              usage: snapshot.weekly)
    }

    private func check(provider: Provider, window: WindowKind, label: String, usage: WindowUsage) {
        let key = Key(provider: provider, window: window)
        var state = states[key] ?? State(firedMax: 0, resetsAt: usage.resetsAt)

        // Window reset detected → re-arm.
        if state.resetsAt != usage.resetsAt {
            state = State(firedMax: 0, resetsAt: usage.resetsAt)
        }

        for t in Self.thresholds where usage.usedPercent >= Double(t) && state.firedMax < t {
            dispatcher.send(NotificationContent(
                title: "\(provider.displayName) \(label) usage at \(t)%",
                body: resetText(usage.resetsAt)
            ))
            state.firedMax = t
        }
        states[key] = state
    }

    private func resetText(_ resetsAt: Date?) -> String {
        guard let r = resetsAt else { return "Approaching your limit." }
        let mins = max(0, Int(r.timeIntervalSinceNow / 60))
        if mins >= 60 { return "Resets in \(mins / 60)h \(mins % 60)m." }
        return "Resets in \(mins)m."
    }
}

private extension Provider {
    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex:  return "Codex"
        }
    }
}
