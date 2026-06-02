import Foundation
import BurnrateCore

/// Fetches live Codex (ChatGPT plan) usage from the undocumented
/// `https://chatgpt.com/backend-api/codex/usage` endpoint, using the OAuth token
/// Codex CLI stores in ~/.codex/auth.json. The access token expires ~hourly; on a
/// 401 we refresh it with the stored refresh_token (in memory only — we never
/// rewrite auth.json, to avoid disturbing Codex's own auth).
final class CodexLiveProvider: @unchecked Sendable {
    private let authPath: URL
    private let usageURL = URL(string: "https://chatgpt.com/backend-api/codex/usage")!
    private let tokenURL = URL(string: "https://auth.openai.com/oauth/token")!
    private let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    private var cachedAccess: String?

    init(authPath: URL? = nil) {
        self.authPath = authPath
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/auth.json")
    }

    private struct Auth { let access: String; let refresh: String?; let account: String }

    private func readAuth() -> Auth? {
        guard let data = try? Data(contentsOf: authPath),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = obj["tokens"] as? [String: Any],
              let access = tokens["access_token"] as? String else { return nil }
        return Auth(
            access: access,
            refresh: tokens["refresh_token"] as? String,
            account: tokens["account_id"] as? String ?? ""
        )
    }

    func snapshot(now: Date) async -> UsageSnapshot {
        guard let auth = readAuth() else { return .unavailable(.codex, asOf: now) }

        // Try cached (refreshed) token first if we have one, else the on-disk token.
        if let snap = await fetch(token: cachedAccess ?? auth.access, account: auth.account, now: now) {
            return snap
        }
        // Likely expired → refresh with the stored refresh token and retry once.
        if let refresh = auth.refresh, let newAccess = await refreshToken(refresh) {
            cachedAccess = newAccess
            if let snap = await fetch(token: newAccess, account: auth.account, now: now) {
                return snap
            }
        }
        return .unavailable(.codex, asOf: now)
    }

    /// 200 → snapshot; anything else (incl. 401) → nil so the caller can refresh.
    private func fetch(token: String, account: String, now: Date) async -> UsageSnapshot? {
        var req = URLRequest(url: usageURL)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(account, forHTTPHeaderField: "ChatGPT-Account-Id")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let parsed = try? CodexUsageResponse.decode(from: data) else { return nil }
        return parsed.snapshot(now: now)
    }

    private func refreshToken(_ refresh: String) async -> String? {
        var req = URLRequest(url: tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": refresh
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = obj["access_token"] as? String else { return nil }
        return access
    }
}
