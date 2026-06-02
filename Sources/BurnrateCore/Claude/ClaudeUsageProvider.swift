import Foundation

public final class ClaudeUsageProvider: @unchecked Sendable {
    public static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    private let tokenStore: TokenStore
    private let http: HTTPClient

    public init(tokenStore: TokenStore, http: HTTPClient) {
        self.tokenStore = tokenStore
        self.http = http
    }

    public func fetch(now: Date) async -> UsageSnapshot {
        guard let token = tokenStore.accessToken() else {
            return .unavailable(.claude, asOf: now)
        }
        let headers = [
            "Authorization": "Bearer \(token)",
            "anthropic-beta": "oauth-2025-04-20"
        ]
        do {
            let resp = try await http.get(url: Self.usageURL, headers: headers)
            switch resp.statusCode {
            case 200:
                let parsed = try OAuthUsageResponse.decode(from: resp.body)
                return UsageSnapshot(
                    provider: .claude,
                    fiveHour: WindowUsage(usedPercent: parsed.fiveHour.utilization, resetsAt: parsed.fiveHour.resetsAt),
                    weekly: WindowUsage(usedPercent: parsed.sevenDay.utilization, resetsAt: parsed.sevenDay.resetsAt),
                    asOf: now,
                    status: .ok
                )
            case 401, 403:
                return .unavailable(.claude, asOf: now)
            default: // 429, 5xx, etc. → keep showing last good (caller decides); mark stale
                return UsageSnapshot.staleClaude(asOf: now)
            }
        } catch {
            return UsageSnapshot.staleClaude(asOf: now)
        }
    }
}

private extension UsageSnapshot {
    static func staleClaude(asOf: Date) -> UsageSnapshot {
        UsageSnapshot(
            provider: .claude,
            fiveHour: WindowUsage(usedPercent: 0, resetsAt: nil),
            weekly: WindowUsage(usedPercent: 0, resetsAt: nil),
            asOf: asOf,
            status: .stale
        )
    }
}
