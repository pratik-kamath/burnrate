import SwiftUI
import BurnrateCore

/// One provider's gauge: two concentric rings (inner = 5-hour, outer = weekly),
/// the 5-hour % in the center, and provider name + weekly%/reset beneath.
struct RingView: View {
    let title: String
    let tint: Color
    let snapshot: UsageSnapshot

    private var available: Bool { snapshot.status != .unavailable }

    private var level: UsageLevel {
        UsageLevel(fiveHourPercent: snapshot.fiveHour.usedPercent,
                   weeklyPercent: snapshot.weekly.usedPercent)
    }
    private var accent: Color {
        switch level {
        case .normal: return tint
        case .amber:  return .orange
        case .red:    return .red
        }
    }
    private var fiveHourFraction: Double { available ? min(1, snapshot.fiveHour.usedPercent / 100) : 0 }
    private var weeklyFraction: Double { available ? min(1, snapshot.weekly.usedPercent / 100) : 0 }

    var body: some View {
        VStack(spacing: 9) {
            ZStack {
                // Outer ring = weekly
                Circle().stroke(.white.opacity(0.10), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: weeklyFraction)
                    .stroke(accent.opacity(0.45), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.5), value: weeklyFraction)

                // Inner ring = 5-hour (inset)
                Circle().stroke(.white.opacity(0.10), lineWidth: 5).padding(11)
                Circle()
                    .trim(from: 0, to: fiveHourFraction)
                    .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(11)
                    .animation(.smooth(duration: 0.5), value: fiveHourFraction)

                Text(centerText)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .frame(width: 78, height: 78)

            VStack(spacing: 1) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(tint)
                Text(subText)
                    .font(.system(size: 9, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false) // don't clamp to the ring width
            }
        }
        .opacity(snapshot.status == .stale ? 0.5 : 1)
        .help(available ? "" : unavailableHelp)
    }

    private var centerText: String {
        available ? "\(Int(snapshot.fiveHour.usedPercent.rounded()))%" : "—"
    }
    private var subText: String {
        guard available else { return "no data" }
        let wk = Int(snapshot.weekly.usedPercent.rounded())
        if let r = snapshot.fiveHour.resetsAt {
            return "wk \(wk)% · \(reset(r))"
        }
        return "wk \(wk)%"
    }
    private var unavailableHelp: String {
        snapshot.provider == .claude ? "Sign in to Claude Code" : "Sign in to Codex"
    }
    private func reset(_ d: Date) -> String {
        let m = max(0, Int(d.timeIntervalSinceNow / 60))
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }
}
