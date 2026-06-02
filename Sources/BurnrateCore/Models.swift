import Foundation

public let burnrateCoreVersion = "0.0.1"

public enum Provider: String, Sendable, CaseIterable {
    case claude
    case codex
}

public enum UsageStatus: Sendable, Equatable {
    case ok          // fresh, trustworthy
    case stale       // last good value, refresh failed
    case unavailable // no data / not signed in
}

public struct WindowUsage: Sendable, Equatable {
    public let usedPercent: Double   // 0...100
    public let resetsAt: Date?
    public init(usedPercent: Double, resetsAt: Date?) {
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
    }
}

public struct UsageSnapshot: Sendable, Equatable {
    public let provider: Provider
    public let fiveHour: WindowUsage
    public let weekly: WindowUsage
    public let asOf: Date
    public let status: UsageStatus
    public init(provider: Provider, fiveHour: WindowUsage, weekly: WindowUsage, asOf: Date, status: UsageStatus) {
        self.provider = provider
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.asOf = asOf
        self.status = status
    }

    /// An "empty/unknown" snapshot for a provider with no data yet.
    public static func unavailable(_ provider: Provider, asOf: Date) -> UsageSnapshot {
        UsageSnapshot(
            provider: provider,
            fiveHour: WindowUsage(usedPercent: 0, resetsAt: nil),
            weekly: WindowUsage(usedPercent: 0, resetsAt: nil),
            asOf: asOf,
            status: .unavailable
        )
    }
}
