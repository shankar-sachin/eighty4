import SwiftUI

/// A built-in app that renders on the LCD and is driven by the keypad.
protocol Game: AnyObject {
    var title: String { get }
    func update(now: TimeInterval)
    func press(_ key: KeyID)
    func draw(_ ctx: inout GraphicsContext, size: CGSize)
    /// Full key info: the raw key plus what it resolves to under the current 2nd/alpha modifier.
    func handle(_ key: KeyID, _ action: KeyAction)
    /// Set by an app that wants to return to the home screen.
    var wantsExit: Bool { get }
    /// Apps that use CLEAR themselves; games let CLEAR quit directly.
    var handlesClear: Bool { get }
}

extension Game {
    func handle(_ key: KeyID, _ action: KeyAction) { press(key) }
    var wantsExit: Bool { false }
    var handlesClear: Bool { false }
}

extension GraphicsContext {
    func drawText(_ s: String, at p: CGPoint, size: CGFloat = 11, weight: Font.Weight = .bold, color: Color = .white, anchor: UnitPoint = .topLeading) {
        draw(Text(s).font(.system(size: size, weight: weight, design: .monospaced)).foregroundColor(color), at: p, anchor: anchor)
    }
}
