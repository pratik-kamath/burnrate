public enum UsageLevel: Sendable, Equatable {
    case normal  // < 75
    case amber   // 75...90
    case red     // > 90

    public init(fiveHourPercent: Double, weeklyPercent: Double) {
        let p = max(fiveHourPercent, weeklyPercent)
        switch p {
        case ..<75:    self = .normal
        case 75...90:  self = .amber
        default:       self = .red
        }
    }
}
