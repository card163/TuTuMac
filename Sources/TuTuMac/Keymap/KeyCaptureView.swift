import SwiftUI
import AppKit

/// 一个透明的 NSView,用于在按键映射编辑器内捕获下一次按键并回调。
struct KeyCaptureView: NSViewRepresentable {
    let onKeyDown: (UInt16, String) -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onKeyDown = onKeyDown
    }
}

final class KeyCaptureNSView: NSView {
    var onKeyDown: ((UInt16, String) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        let characters = event.charactersIgnoringModifiers?.uppercased() ?? "?"
        onKeyDown?(event.keyCode, characters)
    }
}
