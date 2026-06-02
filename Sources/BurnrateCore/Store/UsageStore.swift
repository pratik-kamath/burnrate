import Foundation
import Combine

@MainActor
public final class UsageStore: ObservableObject {
    @Published public private(set) var claude: UsageSnapshot
    @Published public private(set) var codex: UsageSnapshot

    public init(now: Date = Date()) {
        self.claude = .unavailable(.claude, asOf: now)
        self.codex = .unavailable(.codex, asOf: now)
    }

    public func update(_ snapshot: UsageSnapshot) {
        switch snapshot.provider {
        case .claude: claude = snapshot
        case .codex:  codex = snapshot
        }
    }
}
