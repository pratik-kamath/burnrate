import SwiftUI
import BurnrateCore

struct OverlayView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        HStack(spacing: 18) {
            RingView(title: "Claude",
                     tint: Color(red: 0.86, green: 0.53, blue: 0.39),
                     snapshot: store.claude)
            RingView(title: "Codex",
                     tint: Color(red: 0.20, green: 0.80, blue: 0.60),
                     snapshot: store.codex)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .padding(12) // transparent room for the shadow inside the window bounds
    }
}
