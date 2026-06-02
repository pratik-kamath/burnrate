public protocol TokenStore: Sendable {
    /// Returns the Claude OAuth access token, or nil if unavailable / not signed in.
    func accessToken() -> String?
}
