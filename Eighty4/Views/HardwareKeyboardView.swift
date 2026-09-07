import SwiftUI
import UIKit

/// Invisible first responder that forwards hardware-keyboard presses to the calculator.
/// Zero-sized; it only exists to receive `pressesBegan`.
struct HardwareKeyboardView: UIViewRepresentable {
    let onKey: (HardwareKey) -> Bool

    func makeUIView(context: Context) -> KeyCatcherView {
        let v = KeyCatcherView()
        v.onKey = onKey
        return v
    }

    func updateUIView(_ v: KeyCatcherView, context: Context) {
        v.onKey = onKey
        v.grabFocus()
    }
}

final class KeyCatcherView: UIView {
    var onKey: ((HardwareKey) -> Bool)?
    private var activeObserver: NSObjectProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.grabFocus() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        if let o = activeObserver { NotificationCenter.default.removeObserver(o) }
    }

    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        grabFocus()
    }

    /// Becomes first responder once the view is in a window; safe to call repeatedly.
    func grabFocus() {
        guard window != nil, !isFirstResponder else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window != nil, !self.isFirstResponder else { return }
            self.becomeFirstResponder()
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled = Set<UIPress>()
        for p in presses {
            if let key = p.key, let hk = Self.translate(key), onKey?(hk) == true { continue }
            unhandled.insert(p)
        }
        if !unhandled.isEmpty { super.pressesBegan(unhandled, with: event) }
    }

    static func translate(_ key: UIKey) -> HardwareKey? {
        switch key.keyCode {
        case .keyboardReturnOrEnter, .keypadEnter: return .enter
        case .keyboardDeleteOrBackspace: return .backspace
        case .keyboardDeleteForward: return .forwardDelete
        case .keyboardEscape: return .escape
        case .keyboardUpArrow: return .up
        case .keyboardDownArrow: return .down
        case .keyboardLeftArrow: return .left
        case .keyboardRightArrow: return .right
        case .keyboardF1: return .function(1)
        case .keyboardF2: return .function(2)
        case .keyboardF3: return .function(3)
        case .keyboardF4: return .function(4)
        case .keyboardF5: return .function(5)
        default: break
        }
        // Leave ⌘/⌃ shortcuts to the system; shift and option are needed for "(" "π" "√" etc.
        if key.modifierFlags.contains(.command) || key.modifierFlags.contains(.control) { return nil }
        guard key.characters.count == 1, let c = key.characters.first else { return nil }
        return .char(c)
    }
}
