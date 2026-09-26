import AppKit
import SwiftUI

/// Share the last editor size across windows without persisting document content.
struct WindowFramePersistence: NSViewRepresentable {
    var onWindow: (NSWindow) -> Void = { _ in }
    func makeNSView(context: Context) -> FrameView {
        let view = FrameView()
        view.onWindow = onWindow
        return view
    }
    func updateNSView(_ nsView: FrameView, context: Context) {}

    final class FrameView: NSView {
        var onWindow: (NSWindow) -> Void = { _ in }
        private weak var configuredWindow: NSWindow?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, window !== configuredWindow else { return }
            NotificationCenter.default.removeObserver(self)
            configuredWindow = window
            onWindow(window)
            let defaults = UserDefaults.standard
            let width = defaults.double(forKey: "editorWindowWidth")
            let height = defaults.double(forKey: "editorWindowHeight")
            if width.isFinite, height.isFinite, width >= 860, height >= 640 {
                let available = window.screen?.visibleFrame.size ?? NSSize(width: 1120, height: 780)
                window.setContentSize(NSSize(width: min(width, available.width), height: min(height, available.height - 50)))
            }
            NotificationCenter.default.addObserver(self, selector: #selector(resized), name: NSWindow.didResizeNotification, object: window)
        }

        @objc private func resized(_ notification: Notification) {
            guard let window = configuredWindow, !window.styleMask.contains(.fullScreen),
                  let size = window.contentView?.bounds.size else { return }
            UserDefaults.standard.set(size.width, forKey: "editorWindowWidth")
            UserDefaults.standard.set(size.height, forKey: "editorWindowHeight")
        }
    }
}
