import SwiftUI
import BurnrateCore

struct RingView: View {
    let title: String
    let tint: Color
    let snapshot: UsageSnapshot
    @State private var hovering = false

    private var level: UsageLevel {
        UsageLevel(fiveHourPercent: snapshot.fiveHour.usedPercent,
                   weeklyPercent: snapshot.weekly.usedPercent)
    }
    private var ringColor: Color {
        switch level {
        case .normal: return tint
        case .amber:  return .orange
        case .red:    return .red
        }
    }
    private var fraction: Double { min(1, snapshot.fiveHour.usedPercent / 100) }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: snapshot.status == .unavailable ? 0 : fraction)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(centerText)
                    .font(.system(size: 15, weight: .bold)).monospacedDigit()
            }
            .frame(width: 62, height: 62)
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint)
            if hovering { detail }
        }
        .opacity(snapshot.status == .stale ? 0.55 : 1)
        .onHover { hovering = $0 }
        .help(snapshot.status == .unavailable ? unavailableHelp : "")
    }

    private var centerText: String {
        snapshot.status == .unavailable ? "—" : "\(Int(snapshot.fiveHour.usedPercent.rounded()))%"
    }
    private var unavailableHelp: String {
        snapshot.provider == .claude ? "Sign in to Claude Code" : "Run Codex to populate usage"
    }
    private var detail: some View {
        VStack(spacing: 2) {
            Text("Weekly \(Int(snapshot.weekly.usedPercent.rounded()))%")
            if let r = snapshot.fiveHour.resetsAt {
                Text("5h resets \(reset(r))")
            }
        }
        .font(.system(size: 10)).foregroundStyle(.secondary)
    }
    private func reset(_ d: Date) -> String {
        let m = max(0, Int(d.timeIntervalSinceNow / 60))
        return m >= 60 ? "\(m/60)h \(m%60)m" : "\(m)m"
    }
}
