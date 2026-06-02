import Foundation

/// Decodes the live `https://chatgpt.com/backend-api/codex/usage` response.
/// Shape: { "rate_limit": { "primary_window": {used_percent, reset_at},
///                          "secondary_window": {used_percent, reset_at} } }
/// primary_window = 5-hour window, secondary_window = weekly. reset_at = epoch seconds.
public struct CodexUsageResponse: Sendable, Equatable {
    public struct Window: Sendable, Equatable {
        public let usedPercent: Double
        public let resetAt: Date?
    }
    public let primary: Window
    public let secondary: Window

    private struct Raw: Decodable {
        struct RL: Decodable { let primary_window: W?; let secondary_window: W? }
        struct W: Decodable { let used_percent: Double?; let reset_at: Double? }
        let rate_limit: RL?
    }

    public static func decode(from data: Data) throws -> CodexUsageResponse {
        let raw = try JSONDecoder().decode(Raw.self, from: data)
        func map(_ w: Raw.W?) -> Window {
            Window(
                usedPercent: w?.used_percent ?? 0,
                resetAt: w?.reset_at.map { Date(timeIntervalSince1970: $0) }
            )
        }
        return CodexUsageResponse(
            primary: map(raw.rate_limit?.primary_window),
            secondary: map(raw.rate_limit?.secondary_window)
        )
    }

    public func snapshot(now: Date) -> UsageSnapshot {
        UsageSnapshot(
            provider: .codex,
            fiveHour: WindowUsage(usedPercent: primary.usedPercent, resetsAt: primary.resetAt),
            weekly: WindowUsage(usedPercent: secondary.usedPercent, resetsAt: secondary.resetAt),
            asOf: now,
            status: .ok
        )
    }
}
