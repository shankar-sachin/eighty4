import SwiftUI

/// Conics: graph circles, ellipses, hyperbolas and parabolas and list their characteristics.
final class ConicsApp: Game {
    let title = "CONICS"
    private(set) var wantsExit = false
    let handlesClear = true

    private enum Mode { case main, form, params, graph, info }
    private var mode: Mode = .main
    private var kind = 0        // 0 circle, 1 ellipse, 2 hyperbola, 3 parabola
    private var form = 0
    private var fields: [AppField] = []
    private var row = 0
    private let store: VariableStore

    init(store: VariableStore) { self.store = store }

    func update(now: TimeInterval) {}
    func press(_ key: KeyID) {}

    private var paramNames: [String] {
        switch kind {
        case 0: return ["H", "K", "R"]
        case 1, 2: return ["H", "K", "A", "B"]
        default: return ["H", "K", "P"]
        }
    }

    private var forms: [String] {
        switch kind {
        case 0: return ["(X−H)²+(Y−K)²=R²", "(X−H)²+(Y−K)²=R²"]
        case 1: return ["(X−H)²/A²+(Y−K)²/B²=1", "(X−H)²/B²+(Y−K)²/A²=1"]
        case 2: return ["(X−H)²/A²−(Y−K)²/B²=1", "(Y−K)²/A²−(X−H)²/B²=1"]
        default: return ["(Y−K)²=4P(X−H)", "(X−H)²=4P(Y−K)"]
        }
    }

    private func value(_ i: Int) -> Double { fields[i].number(store) ?? 0 }

    func handle(_ key: KeyID, _ action: KeyAction) {
        switch mode {
        case .main:
            if let d = AppUI.digit(action), d >= 1, d <= 4 { kind = d - 1; mode = .form; return }
            switch action {
            case .up: kind = (kind + 3) % 4
            case .down: kind = (kind + 1) % 4
            case .enter: mode = .form
            case .clear: wantsExit = true
            default: break
            }
        case .form:
            if let d = AppUI.digit(action), d >= 1, d <= 2 { form = d - 1; startParams(); return }
            switch action {
            case .up, .down: form = 1 - form
            case .enter: startParams()
            case .clear: mode = .main
            default: break
            }
        case .params:
            if AppUI.fkey(key) == 5 { mode = .graph; return }
            if AppUI.fkey(key) == 4 { mode = .info; return }
            if AppUI.fkey(key) == 1 { mode = .main; return }
            switch action {
            case .up: row = max(0, row - 1)
            case .down: row = min(fields.count - 1, row + 1)
            case .enter: if row < fields.count - 1 { row += 1 } else { mode = .info }
            case .clear: if fields[row].chars.isEmpty { mode = .form } else { fields[row].chars = [] }
            default: _ = fields[row].apply(action)
            }
        case .graph, .info:
            if AppUI.fkey(key) == 5 { mode = .graph }
            else if AppUI.fkey(key) == 4 { mode = .info }
            else if AppUI.fkey(key) == 1 { mode = .main }
            else if action == .clear || action == .enter { mode = .params }
        }
    }

    private func startParams() {
        fields = paramNames.map { _ in AppField() }
        row = 0
        mode = .params
    }

    // MARK: - Geometry

    private struct Info { var lines: [String]; var points: [(Double, Double)] }

    private func info() -> Info {
        let h = value(0), k = value(1)
        func f(_ v: Double) -> String { AppUI.short(v, 4) }
        switch kind {
        case 0:
            let r = abs(value(2))
            return Info(lines: ["CENTER (\(f(h)),\(f(k)))", "RADIUS \(f(r))", "AREA \(f(.pi * r * r))", "CIRCUMF \(f(2 * .pi * r))"], points: [(h, k)])
        case 1:
            let a = abs(value(2)), b = abs(value(3))
            let major = max(a, b), minor = min(a, b)
            let c = sqrt(max(0, major * major - minor * minor))
            let horizontal = (form == 0) == (a >= b)
            let v1 = horizontal ? (h - major, k) : (h, k - major), v2 = horizontal ? (h + major, k) : (h, k + major)
            let f1 = horizontal ? (h - c, k) : (h, k - c), f2 = horizontal ? (h + c, k) : (h, k + c)
            return Info(lines: ["CENTER (\(f(h)),\(f(k)))", "VERTICES (\(f(v1.0)),\(f(v1.1)))", "         (\(f(v2.0)),\(f(v2.1)))", "FOCI (\(f(f1.0)),\(f(f1.1)))", "     (\(f(f2.0)),\(f(f2.1)))", "ECCENTRICITY \(f(major == 0 ? 0 : c / major))"], points: [(h, k), f1, f2])
        case 2:
            let a = abs(value(2)), b = abs(value(3))
            let c = sqrt(a * a + b * b)
            let horizontal = form == 0
            let v1 = horizontal ? (h - a, k) : (h, k - a), v2 = horizontal ? (h + a, k) : (h, k + a)
            let f1 = horizontal ? (h - c, k) : (h, k - c), f2 = horizontal ? (h + c, k) : (h, k + c)
            let slope = horizontal ? b / max(1e-9, a) : a / max(1e-9, b)
            return Info(lines: ["CENTER (\(f(h)),\(f(k)))", "VERTICES (\(f(v1.0)),\(f(v1.1)))", "         (\(f(v2.0)),\(f(v2.1)))", "FOCI (\(f(f1.0)),\(f(f1.1)))", "     (\(f(f2.0)),\(f(f2.1)))", "ASYMPT SLOPE ±\(f(slope))", "ECCENTRICITY \(f(a == 0 ? 0 : c / a))"], points: [(h, k), f1, f2])
        default:
            let p = value(2)
            let focus = form == 0 ? (h + p, k) : (h, k + p)
            let directrix = form == 0 ? "X=\(f(h - p))" : "Y=\(f(k - p))"
            return Info(lines: ["VERTEX (\(f(h)),\(f(k)))", "FOCUS (\(f(focus.0)),\(f(focus.1)))", "DIRECTRIX \(directrix)", "AXIS " + (form == 0 ? "Y=\(f(k))" : "X=\(f(h))")], points: [(h, k), focus])
        }
    }

    private func curvePoints() -> [[(Double, Double)]] {
        let h = value(0), k = value(1)
        switch kind {
        case 0:
            let r = abs(value(2))
            return [stride(from: 0.0, through: 2 * .pi + 0.01, by: 0.02).map { (h + r * cos($0), k + r * sin($0)) }]
        case 1:
            let a = abs(value(2)), b = abs(value(3))
            let (rx, ry) = form == 0 ? (a, b) : (b, a)
            return [stride(from: 0.0, through: 2 * .pi + 0.01, by: 0.02).map { (h + rx * cos($0), k + ry * sin($0)) }]
        case 2:
            let a = abs(value(2)), b = abs(value(3))
            let ts = stride(from: -3.0, through: 3.0, by: 0.02)
            if form == 0 {
                return [ts.map { (h + a * cosh($0), k + b * sinh($0)) }, ts.map { (h - a * cosh($0), k + b * sinh($0)) }]
            }
            return [ts.map { (h + b * sinh($0), k + a * cosh($0)) }, ts.map { (h + b * sinh($0), k - a * cosh($0)) }]
        default:
            let p = value(2)
            let span = max(1, abs(p) * 6)
            let ts = stride(from: -span, through: span, by: span / 100)
            if form == 0 { return [ts.map { (h + $0 * $0 / (4 * (p == 0 ? 1e-9 : p)), k + $0) }] }
            return [ts.map { (h + $0, k + $0 * $0 / (4 * (p == 0 ? 1e-9 : p))) }]
        }
    }

    private func window() -> GraphWindow {
        let h = value(0), k = value(1)
        var half: Double
        switch kind {
        case 0: half = abs(value(2))
        case 1, 2: half = max(abs(value(2)), abs(value(3))) * (kind == 2 ? 2 : 1)
        default: half = max(1, abs(value(2)) * 4)
        }
        half = max(1, half) * 1.4
        Graphing.setWindow(store, h - half * 320 / 218, h + half * 320 / 218, max(1, (half / 5).rounded()), k - half, k + half, max(1, (half / 5).rounded()))
        return GraphWindow(store: store)
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        switch mode {
        case .main:
            AppUI.menu(&ctx, title: "CONICS", items: ["CIRCLE", "ELLIPSE", "HYPERBOLA", "PARABOLA"], selected: kind)
            AppUI.text(&ctx, "CLEAR quits", row: 8, col: 0)
        case .form:
            AppUI.text(&ctx, ["CIRCLE", "ELLIPSE", "HYPERBOLA", "PARABOLA"][kind], row: 0, col: 0, inverted: true)
            for (i, f) in forms.enumerated() {
                AppUI.text(&ctx, "\(i + 1)", row: 2 + i * 2, col: 0, inverted: i == form)
                AppUI.text(&ctx, ":" + f, row: 2 + i * 2, col: 1)
            }
        case .params:
            AppUI.text(&ctx, forms[form], row: 0, col: 0, inverted: true)
            for (i, name) in paramNames.enumerated() {
                AppUI.text(&ctx, name + "=", row: 2 + i, col: 1)
                AppUI.text(&ctx, fields[i].text, row: 2 + i, col: 3, inverted: i == row)
                if i == row { AppUI.text(&ctx, "_", row: 2 + i, col: 3 + fields[i].chars.count) }
            }
            AppUI.softkeys(&ctx, ["MAIN", "", "", "INFO", "GRAPH"], size: size)
        case .graph:
            let w = window()
            GraphRenderer.drawGrid(&ctx, size, w, store)
            for pts in curvePoints() {
                var p = Path()
                var pen = false
                for (x, y) in pts {
                    let pt = CGPoint(x: w.px(x, size), y: w.py(y, size))
                    guard pt.x.isFinite, pt.y.isFinite, abs(pt.x) < 5000, abs(pt.y) < 5000 else { pen = false; continue }
                    if pen { p.addLine(to: pt) } else { p.move(to: pt); pen = true }
                }
                ctx.stroke(p, with: .color(GraphRenderer.color(1)), lineWidth: 2)
            }
            for (x, y) in info().points {
                ctx.fill(Path(ellipseIn: CGRect(x: w.px(x, size) - 2, y: w.py(y, size) - 2, width: 4, height: 4)), with: .color(.red))
            }
            AppUI.softkeys(&ctx, ["MAIN", "", "", "INFO", ""], size: size)
        case .info:
            AppUI.text(&ctx, forms[form], row: 0, col: 0, inverted: true)
            for (i, l) in info().lines.prefix(7).enumerated() { AppUI.text(&ctx, l, row: 1 + i, col: 0) }
            AppUI.softkeys(&ctx, ["MAIN", "", "", "", "GRAPH"], size: size)
        }
    }
}
