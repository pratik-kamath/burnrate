import Foundation

public struct OAuthUsageResponse: Sendable, Equatable {
    public struct Window: Sendable, Equatable {
        public let utilization: Double
        public let resetsAt: Date?
    }
    public let fiveHour: Window
    public let sevenDay: Window

    private struct Raw: Decodable {
        struct W: Decodable { let utilization: Double?; let resets_at: String? }
        let five_hour: W?
        let seven_day: W?
    }

    public static func decode(from data: Data) throws -> OAuthUsageResponse {
        let raw = try JSONDecoder().decode(Raw.self, from: data)
        let fmt = ISO8601DateFormatter()
        func map(_ w: Raw.W?) -> Window {
            Window(
                utilization: w?.utilization ?? 0,
                resetsAt: w?.resets_at.flatMap { fmt.date(from: $0) }
            )
        }
        return OAuthUsageResponse(fiveHour: map(raw.five_hour), sevenDay: map(raw.seven_day))
    }
}
