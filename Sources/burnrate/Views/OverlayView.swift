import SwiftUI
import BurnrateCore

struct OverlayView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        HStack(spacing: 18) {
            RingView(title: "Claude", tint: Color(red: 0.91, green: 0.66, blue: 0.49), snapshot: store.claude)
            RingView(title: "Codex", tint: Color(red: 0.24, green: 0.85, blue: 0.66), snapshot: store.codex)
        }
        .padding(14)
        .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
    }
}
