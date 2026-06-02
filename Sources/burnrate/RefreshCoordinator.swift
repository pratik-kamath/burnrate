import Foundation
import BurnrateCore

@MainActor
final class RefreshCoordinator {
    private let store: UsageStore
    private let claude: ClaudeUsageProvider
    private let codex: CodexUsageProvider
    private let notifier: MilestoneNotifier

    private var claudeBackoff = BackoffPolicy()
    private var codexTimer: Timer?
    private var claudeTask: Task<Void, Never>?

    init(store: UsageStore, claude: ClaudeUsageProvider, codex: CodexUsageProvider, notifier: MilestoneNotifier) {
        self.store = store
        self.claude = claude
        self.codex = codex
        self.notifier = notifier
    }

    func start() {
        // Codex: cheap local read every 30s.
        refreshCodex()
        codexTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshCodex() }
        }
        // Claude: self-rescheduling loop honoring backoff.
        scheduleClaude(after: 0)
    }

    func refreshNow() {
        refreshCodex()
        claudeTask?.cancel()
        scheduleClaude(after: 0)
    }

    private func refreshCodex() {
        let snap = codex.snapshot(now: Date())
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
