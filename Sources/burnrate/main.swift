import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)   // no Dock icon; overlay only
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
