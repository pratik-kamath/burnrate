import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {
    init<Content: View>(content: Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 230, height: 130),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        isFloatingPanel = false
        // Sit on the desktop: just above the desktop icons, but below all normal
        // app windows — so it lives on the wallpaper and never covers your work.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false   // use the SwiftUI shadow instead; the window shadow double-frames a transparent panel
        isMovableByWindowBackground = true
        let host = NSHostingView(rootView: content)
        host.layoutSubtreeIfNeeded()
        let fit = host.fittingSize
        setContentSize(fit)
        host.frame = NSRect(origin: .zero, size: fit)
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
