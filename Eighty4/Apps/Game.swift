import SwiftUI

/// A built-in app that renders on the LCD and is driven by the keypad.
protocol Game: AnyObject {
    var title: String { get }
    func update(now: TimeInterval)
    func press(_ key: KeyID)
    func draw(_ ctx: inout GraphicsContext, size: CGSize)
}

extension GraphicsContext {
    func drawText(_ s: String, at p: CGPoint, size: CGFloat = 11, weight: Font.Weight = .bold, color: Color = .white, anchor: UnitPoint = .topLeading) {
        draw(Text(s).font(.system(size: size, weight: weight, design: .monospaced)).foregroundColor(color), at: p, anchor: anchor)
    }
}
