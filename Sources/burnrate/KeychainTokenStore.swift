import Foundation
import Security
import BurnrateCore

/// Reads the Claude Code OAuth token from the macOS Keychain.
/// Claude Code stores a generic-password item (service "Claude Code-credentials")
/// whose value is JSON like {"claudeAiOauth":{"accessToken":"..."}}.
/// On first read macOS prompts to allow access; choose "Always Allow".
struct KeychainTokenStore: TokenStore {
    let service: String

    init(service: String = "Claude Code-credentials") {
        self.service = service
    }

    func accessToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = obj["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String
        else { return nil }
        return token
    }
}
