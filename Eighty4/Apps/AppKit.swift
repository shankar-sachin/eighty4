import SwiftUI

/// Cell-grid drawing helpers for apps that render in a Canvas.
enum AppUI {
    static let cellW: CGFloat = 12
    static let lineH: CGFloat = 21
    static let leftPad: CGFloat = 4
    static let cols = 26
    static let rows = 10

    static func text(_ ctx: inout GraphicsContext, _ s: String, row: Int, col: Int, inverted: Bool = false, color: Color = .black) {
        for (i, ch) in s.enumerated() where col + i < cols {
            let x = leftPad + CGFloat(col + i) * cellW
            let y = CGFloat(row) * lineH
            if inverted { ctx.fill(Path(CGRect(x: x, y: y, width: cellW, height: lineH)), with: .color(.black)) }
            ctx.draw(Text(String(ch)).font(LCD.font).foregroundColor(inverted ? .white : color), at: CGPoint(x: x + cellW / 2, y: y + lineH / 2), anchor: .center)
        }
    }

    static func centered(_ ctx: inout GraphicsContext, _ s: String, row: Int, inverted: Bool = false, color: Color = .black) {
        text(&ctx, s, row: row, col: max(0, (cols - s.count) / 2), inverted: inverted, color: color)
    }

    /// Bottom softkey strip: five labels for F1–F5 (y= window zoom trace graph).
    static func softkeys(_ ctx: inout GraphicsContext, _ labels: [String], size: CGSize) {
        let y = size.height - 16
        ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 16)), with: .color(.black))
        let w = size.width / 5
        for (i, l) in labels.prefix(5).enumerated() where !l.isEmpty {
            ctx.drawText(l, at: CGPoint(x: CGFloat(i) * w + w / 2, y: y + 8), size: 10, weight: .bold, color: .white, anchor: .center)
        }
    }

    static func menu(_ ctx: inout GraphicsContext, title: String, items: [String], selected: Int, top: Int = 0) {
        text(&ctx, title, row: top, col: 0, inverted: true)
        for (i, item) in items.enumerated() {
            text(&ctx, "\(i + 1)", row: top + 1 + i, col: 0, inverted: i == selected)
            text(&ctx, ":" + item, row: top + 1 + i, col: 1)
        }
    }

    static func number(_ v: Double) -> String { ResultFormatter.number(v) }

    /// Rounded for display in app screens (avoid 1.0000000001).
    static func short(_ v: Double, _ digits: Int = 6) -> String {
        let p = pow(10.0, Double(digits))
        return ResultFormatter.number((v * p).rounded() / p)
    }

    /// F1–F5 index for the top-row keys, or nil.
    static func fkey(_ key: KeyID) -> Int? {
        switch key {
        case .yEquals: return 1
        case .window: return 2
        case .zoom: return 3
        case .trace: return 4
        case .graph: return 5
        default: return nil
        }
    }

    static func digit(_ action: KeyAction) -> Int? {
        if case .insert(let s) = action, s.count == 1, let d = Int(s) { return d }
        return nil
    }
}

/// A small text field driven by resolved key actions.
struct AppField {
    var chars: [Character] = []
    var text: String {
        get { String(chars) }
        set { chars = Array(newValue) }
    }

    /// Returns true when the action edited the field.
    mutating func apply(_ action: KeyAction) -> Bool {
        switch action {
        case .insert(let s):
            if chars.count + s.count <= 60 { chars += Array(s) }
            return true
        case .del:
            if !chars.isEmpty { chars.removeLast() }
            return true
        default:
            return false
        }
    }

    func number(_ store: VariableStore) -> Double? {
        guard !chars.isEmpty else { return nil }
        return try? Evaluator.number(text, ctx: EvalContext(store: store))
    }
}

/// Complex number used by complex lists/matrices and the polynomial root finder.
struct Cx: Equatable, MatrixScalar {
    var re: Double
    var im: Double

    static var zero: Cx { Cx(re: 0, im: 0) }
    static var one: Cx { Cx(re: 1, im: 0) }
    var magnitude: Double { hypot(re, im) }

    static func + (a: Cx, b: Cx) -> Cx { Cx(re: a.re + b.re, im: a.im + b.im) }
    static func - (a: Cx, b: Cx) -> Cx { Cx(re: a.re - b.re, im: a.im - b.im) }
    static func * (a: Cx, b: Cx) -> Cx { Cx(re: a.re * b.re - a.im * b.im, im: a.re * b.im + a.im * b.re) }
    static func / (a: Cx, b: Cx) -> Cx {
        let d = b.re * b.re + b.im * b.im
        return Cx(re: (a.re * b.re + a.im * b.im) / d, im: (a.im * b.re - a.re * b.im) / d)
    }
    var abs: Double { hypot(re, im) }

    var text: String {
        let r = (re * 1e6).rounded() / 1e6, i = (im * 1e6).rounded() / 1e6
        if i == 0 { return AppUI.number(r) }
        if r == 0 { return AppUI.number(i) + "i" }
        return AppUI.number(r) + (i < 0 ? "−" : "+") + AppUI.number(Swift.abs(i)) + "i"
    }

    /// Durand–Kerner roots of a polynomial with real coefficients, highest power first.
    static func roots(_ coefficients: [Double]) -> [Cx] {
        var c = coefficients
        while c.count > 1, c[0] == 0 { c.removeFirst() }
        let n = c.count - 1
        guard n >= 1, c[0] != 0 else { return [] }
        let a = c.map { $0 / c[0] }
        if n == 1 { return [Cx(re: -a[1], im: 0)] }
        func p(_ z: Cx) -> Cx { a.reduce(Cx(re: 0, im: 0)) { $0 * z + Cx(re: $1, im: 0) } }
        var z: [Cx] = (0..<n).map { k in
            let ang = 2 * Double.pi * Double(k) / Double(n) + 0.4
            let r = 1 + Swift.abs(a.dropFirst().map { Swift.abs($0) }.max() ?? 1)
            return Cx(re: r * cos(ang), im: r * sin(ang))
        }
        for _ in 0..<500 {
            var maxDelta = 0.0
            for i in 0..<n {
                var denom = Cx(re: 1, im: 0)
                for j in 0..<n where j != i { denom = denom * (z[i] - z[j]) }
                if denom.abs < 1e-14 { denom = Cx(re: 1e-14, im: 0) }
                let delta = p(z[i]) / denom
                z[i] = z[i] - delta
                maxDelta = max(maxDelta, delta.abs)
            }
            if maxDelta < 1e-12 { break }
        }
        return z.map { r in
            var r = r
            if Swift.abs(r.im) < 1e-7 { r.im = 0 }
            return r
        }.sorted { ($0.re, $0.im) < ($1.re, $1.im) }
    }
}
