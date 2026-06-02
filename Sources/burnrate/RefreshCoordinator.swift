import Foundation
import BurnrateCore

@MainActor
final class RefreshCoordinator {
    private let store: UsageStore
    private let claude: ClaudeUsageProvider
    private let codex: CodexLiveProvider
    private let notifier: MilestoneNotifier

    private var claudeBackoff = BackoffPolicy()
    private var codexTimer: Timer?
    private var claudeTask: Task<Void, Never>?

    init(store: UsageStore, claude: ClaudeUsageProvider, codex: CodexLiveProvider, notifier: MilestoneNotifier) {
        self.store = store
        self.claude = claude
        self.codex = codex
        self.notifier = notifier
    }

    func start() {
        // Codex: live usage fetch every 60s (read-only endpoint, does not consume quota).
        Task { @MainActor in await refreshCodex() }
        codexTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshCodex() }
        }
        // Claude: self-rescheduling loop honoring backoff.
        scheduleClaude(after: 0)
    }

    func refreshNow() {
        Task { @MainActor in await refreshCodex() }
        claudeTask?.cancel()
        scheduleClaude(after: 0)
    }

    private func refreshCodex() async {
        let snap = await codex.snapshot(now: Date())
        store.update(snap)
        notifier.evaluate(snap)
    }

    private func scheduleClaude(after delay: TimeInterval) {
        claudeTask = Task { @MainActor in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            if Task.isCancelled { return }
            let snap = await claude.fetch(now: Date())
            store.update(snap)
            notifier.evaluate(snap)
            if snap.status == .ok { claudeBackoff.recordSuccess() }
            else if snap.status == .stale { claudeBackoff.recordFailure() }
            scheduleClaude(after: claudeBackoff.currentInterval)
        }
    }

    func stop() {
        codexTimer?.invalidate()
        claudeTask?.cancel()
    }
}
