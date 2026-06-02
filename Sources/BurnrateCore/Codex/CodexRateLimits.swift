import Foundation

public struct CodexRateLimits: Sendable, Equatable {
    public struct Window: Sendable, Equatable {
        public let usedPercent: Double
        public let windowMinutes: Int
        public let resetsAt: Date?
    }
    public let primary: Window
    public let secondary: Window

    // Decodable mirrors of the on-disk JSON.
    private struct Line: Decodable { let payload: Payload? }
    private struct Payload: Decodable { let rate_limits: RawLimits? }
    private struct RawLimits: Decodable { let primary: RawWindow; let secondary: RawWindow }
    private struct RawWindow: Decodable {
        let used_percent: Double
        let window_minutes: Int
        let resets_at: Double?
    }

    private static func map(_ w: RawWindow) -> Window {
        Window(
            usedPercent: w.used_percent,
            windowMinutes: w.window_minutes,
            resetsAt: w.resets_at.map { Date(timeIntervalSince1970: $0) }
        )
    }

    /// Scans lines newest-last; returns the rate_limits from the last line that has them.
    public static func lastRateLimits(inLines lines: [String]) -> CodexRateLimits? {
        let decoder = JSONDecoder()
        for line in lines.reversed() {
            guard let data = line.data(using: .utf8),
                  let decoded = try? decoder.decode(Line.self, from: data),
                  let raw = decoded.payload?.rate_limits else { continue }
            return CodexRateLimits(primary: map(raw.primary), secondary: map(raw.secondary))
        }
        return nil
    }
}
