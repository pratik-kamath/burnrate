import Foundation

/// Decides the polling interval for the Claude usage endpoint, which 429s aggressively.
public struct BackoffPolicy: Sendable {
    public let baseInterval: TimeInterval
    public let maxInterval: TimeInterval
    private var failures: Int = 0

    public init(baseInterval: TimeInterval = 300, maxInterval: TimeInterval = 1200) {
        self.baseInterval = baseInterval
        self.maxInterval = maxInterval
    }

    public var currentInterval: TimeInterval {
        guard failures > 0 else { return baseInterval }
        let scaled = baseInterval * pow(2.0, Double(failures))
        return min(scaled, maxInterval)
    }

    public mutating func recordSuccess() { failures = 0 }
    public mutating func recordFailure() { failures += 1 }
}
