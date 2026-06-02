import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {
    init<Content: View>(content: Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 230, height: 130),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovableByWindowBackground = true
        let host = NSHostingView(rootView: content)
        host.frame = contentView!.bounds
        host.autoresizingMask = [.width, .height]
        contentView?.addSubview(host)
        restorePosition()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    private let posKey = "burnrate.panelOrigin"
    func restorePosition() {
        if let s = UserDefaults.standard.string(forKey: posKey) {
            setFrameOrigin(NSPointFromString(s))
        } else {
            center()
        }
    }
    func savePosition() {
        UserDefaults.standard.set(NSStringFromPoint(frame.origin), forKey: posKey)
    }
}
