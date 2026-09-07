import SwiftUI

/// SciTools: sig-fig calculator, unit converter, data/graphs wizard, vector calculator.
final class SciToolsApp: Game {
    let title = "SCITOOLS"
    private(set) var wantsExit = false
    let handlesClear = true

    private enum Mode { case main, sigFig, unitCategory, unitConvert, dataGraph, vector }
    private var mode: Mode = .main
    private var menuRow = 0
    private let store: VariableStore

    // Sig-fig
    private var sigField = AppField()
    private var sigResult = ""

    // Units
    private struct Category { let name: String; let units: [(String, Double)]; let isTemp: Bool }
    private static let categories: [Category] = [
        Category(name: "LENGTH", units: [("m", 1), ("cm", 0.01), ("mm", 0.001), ("km", 1000), ("in", 0.0254), ("ft", 0.3048), ("yd", 0.9144), ("mi", 1609.344)], isTemp: false),
        Category(name: "AREA", units: [("m²", 1), ("cm²", 1e-4), ("km²", 1e6), ("in²", 6.4516e-4), ("ft²", 0.09290304), ("acre", 4046.8564), ("ha", 1e4)], isTemp: false),
        Category(name: "VOLUME", units: [("L", 1), ("mL", 0.001), ("m³", 1000), ("gal", 3.785411784), ("qt", 0.946352946), ("cup", 0.2365882365), ("fl oz", 0.0295735296)], isTemp: false),
        Category(name: "TIME", units: [("s", 1), ("min", 60), ("hr", 3600), ("day", 86400), ("wk", 604800), ("yr", 31557600)], isTemp: false),
        Category(name: "TEMP", units: [("°C", 1), ("°F", 1), ("K", 1)], isTemp: true),
        Category(name: "MASS", units: [("kg", 1), ("g", 0.001), ("mg", 1e-6), ("lb", 0.45359237), ("oz", 0.028349523), ("ton", 907.18474), ("t", 1000)], isTemp: false),
        Category(name: "FORCE", units: [("N", 1), ("kN", 1000), ("lbf", 4.4482216), ("dyn", 1e-5), ("kgf", 9.80665)], isTemp: false),
        Category(name: "PRESSURE", units: [("Pa", 1), ("kPa", 1000), ("atm", 101325), ("bar", 1e5), ("psi", 6894.757), ("mmHg", 133.3224)], isTemp: false),
        Category(name: "ENERGY", units: [("J", 1), ("kJ", 1000), ("cal", 4.184), ("kcal", 4184), ("kWh", 3.6e6), ("eV", 1.602176634e-19), ("BTU", 1055.056)], isTemp: false),
        Category(name: "POWER", units: [("W", 1), ("kW", 1000), ("hp", 745.6998716), ("BTU/hr", 0.29307107)], isTemp: false),
        Category(name: "SPEED", units: [("m/s", 1), ("km/h", 1 / 3.6), ("mph", 0.44704), ("ft/s", 0.3048), ("knot", 0.514444)], isTemp: false),
    ]
    private var category = 0
    private var fromUnit = 0, toUnit = 1
    private var unitRow = 0
    private var unitField = AppField()

    // Vectors
    private var vec: [AppField] = (0..<4).map { _ in AppField() }
    private var vecRow = 0

    init(store: VariableStore) { self.store = store }

    func update(now: TimeInterval) {}
    func press(_ key: KeyID) {}

    func handle(_ key: KeyID, _ action: KeyAction) {
        switch mode {
        case .main:
            if let d = AppUI.digit(action), d >= 1, d <= 5 { menuRow = d - 1; selectMain(); return }
            switch action {
            case .up: menuRow = (menuRow + 4) % 5
            case .down: menuRow = (menuRow + 1) % 5
            case .enter: selectMain()
            case .clear: wantsExit = true
            default: break
            }
        case .sigFig:
            if AppUI.fkey(key) == 1 { mode = .main; return }
            switch action {
            case .enter: computeSigFig()
            case .clear: if sigField.chars.isEmpty { mode = .main } else { sigField.chars = []; sigResult = "" }
            default: _ = sigField.apply(action)
            }
        case .unitCategory:
            if AppUI.fkey(key) == 1 { mode = .main; return }
            let n = Self.categories.count
            if let d = AppUI.digit(action), d >= 1, d <= n { category = d - 1; mode = .unitConvert; return }
            switch action {
            case .up: category = (category + n - 1) % n
            case .down: category = (category + 1) % n
            case .enter: fromUnit = 0; toUnit = 1; unitRow = 0; mode = .unitConvert
            case .clear: mode = .main
            default: break
            }
        case .unitConvert:
            if AppUI.fkey(key) == 1 { mode = .main; return }
            if AppUI.fkey(key) == 2 { mode = .unitCategory; return }
            let units = Self.categories[category].units.count
            switch action {
            case .up: unitRow = max(0, unitRow - 1)
            case .down, .enter: unitRow = min(2, unitRow + 1)
            case .left:
                if unitRow == 1 { fromUnit = (fromUnit + units - 1) % units } else if unitRow == 2 { toUnit = (toUnit + units - 1) % units }
            case .right:
                if unitRow == 1 { fromUnit = (fromUnit + 1) % units } else if unitRow == 2 { toUnit = (toUnit + 1) % units }
            case .clear: if unitField.chars.isEmpty { mode = .unitCategory } else { unitField.chars = [] }
            default: if unitRow == 0 { _ = unitField.apply(action) }
            }
        case .dataGraph:
            if AppUI.fkey(key) == 1 || action == .clear { mode = .main }
        case .vector:
            if AppUI.fkey(key) == 1 { mode = .main; return }
            switch action {
            case .up: vecRow = max(0, vecRow - 1)
            case .down, .enter: vecRow = min(3, vecRow + 1)
            case .clear: if vec[vecRow].chars.isEmpty { mode = .main } else { vec[vecRow].chars = [] }
            default: _ = vec[vecRow].apply(action)
            }
        }
    }

    private func selectMain() {
        switch menuRow {
        case 0: mode = .sigFig
        case 1: mode = .unitCategory
        case 2: mode = .dataGraph
        case 3: mode = .vector
        default: wantsExit = true
        }
    }

    // MARK: - Sig figs

    private func computeSigFig() {
        let text = sigField.text
        guard let v = try? Evaluator.number(text, ctx: EvalContext(store: store)) else { sigResult = "ERR:SYNTAX"; return }
        // Numbers in the expression.
        var numbers: [String] = []
        var cur = ""
        for ch in text {
            if ch.isNumber || ch == "." { cur.append(ch) } else { if !cur.isEmpty { numbers.append(cur); cur = "" } }
        }
        if !cur.isEmpty { numbers.append(cur) }
        func sigFigs(_ s: String) -> Int {
            let digits = s.replacingOccurrences(of: ".", with: "")
            let trimmed = digits.drop { $0 == "0" }
            if trimmed.isEmpty { return 1 }
            if s.contains(".") { return trimmed.count }
            return String(trimmed).reversed().drop { $0 == "0" }.count
        }
        func decimals(_ s: String) -> Int { s.contains(".") ? s.split(separator: ".").last.map { $0.count } ?? 0 : 0 }
        let multiplicative = text.contains("×") || text.contains("÷") || text.contains("*") || text.contains("/")
        let result: String
        if multiplicative || numbers.count <= 1 {
            let sf = numbers.map(sigFigs).min() ?? 3
            if v == 0 { result = "0" } else {
                let mag = Int(floor(log10(abs(v))))
                let p = pow(10.0, Double(sf - 1 - mag))
                result = AppUI.number((v * p).rounded() / p) + "  (\(sf) sig figs)"
            }
        } else {
            let d = numbers.map(decimals).min() ?? 0
            let p = pow(10.0, Double(d))
            result = String(format: "%.\(d)f", (v * p).rounded() / p) + "  (\(d) decimals)"
        }
        sigResult = "= " + result
    }

    // MARK: - Units

    private func convert(_ v: Double) -> Double {
        let cat = Self.categories[category]
        if cat.isTemp {
            let toC: Double
            switch fromUnit { case 1: toC = (v - 32) * 5 / 9; case 2: toC = v - 273.15; default: toC = v }
            switch toUnit { case 1: return toC * 9 / 5 + 32; case 2: return toC + 273.15; default: return toC }
        }
        return v * cat.units[fromUnit].1 / cat.units[toUnit].1
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        switch mode {
        case .main:
            AppUI.menu(&ctx, title: "SCIENCE TOOLS", items: ["SIG-FIG CALCULATOR", "UNIT CONVERTER", "DATA/GRAPHS WIZARD", "VECTOR CALCULATOR", "QUIT"], selected: menuRow)
        case .sigFig:
            AppUI.text(&ctx, "SIG-FIG CALCULATOR", row: 0, col: 0, inverted: true)
            AppUI.text(&ctx, "Type an expression, ENTER", row: 1, col: 0)
            AppUI.text(&ctx, String(sigField.text.suffix(25)), row: 3, col: 0)
            AppUI.text(&ctx, "_", row: 3, col: min(25, sigField.chars.count))
            AppUI.text(&ctx, sigResult, row: 5, col: 0)
            AppUI.softkeys(&ctx, ["MAIN", "", "", "", ""], size: size)
        case .unitCategory:
            AppUI.text(&ctx, "UNIT CONVERTER", row: 0, col: 0, inverted: true)
            for (i, c) in Self.categories.enumerated() {
                let col = i < 6 ? 0 : 13
                let row = 1 + (i % 6)
                AppUI.text(&ctx, "\(i + 1 == 10 ? "0" : String((i + 1) % 11))", row: row, col: col, inverted: i == category)
                AppUI.text(&ctx, ":" + c.name, row: row, col: col + 1)
            }
            AppUI.softkeys(&ctx, ["MAIN", "", "", "", ""], size: size)
        case .unitConvert:
            let cat = Self.categories[category]
            AppUI.text(&ctx, cat.name, row: 0, col: 0, inverted: true)
            AppUI.text(&ctx, "VALUE", row: 2, col: 1, inverted: unitRow == 0)
            AppUI.text(&ctx, unitField.text + (unitRow == 0 ? "_" : ""), row: 2, col: 8)
            AppUI.text(&ctx, "FROM", row: 4, col: 1, inverted: unitRow == 1)
            AppUI.text(&ctx, "◄ \(cat.units[fromUnit].0) ►", row: 4, col: 8)
            AppUI.text(&ctx, "TO", row: 5, col: 1, inverted: unitRow == 2)
            AppUI.text(&ctx, "◄ \(cat.units[toUnit].0) ►", row: 5, col: 8)
            if let v = unitField.number(store) {
                AppUI.text(&ctx, "= \(AppUI.short(convert(v), 8)) \(cat.units[toUnit].0)", row: 7, col: 1)
            }
            AppUI.softkeys(&ctx, ["MAIN", "UNITS", "", "", ""], size: size)
        case .dataGraph:
            let x = store.lists["L1"] ?? [], y = store.lists["L2"] ?? []
            let n = min(x.count, y.count)
            guard n >= 2 else {
                AppUI.text(&ctx, "DATA/GRAPHS WIZARD", row: 0, col: 0, inverted: true)
                AppUI.text(&ctx, "Enter data in L1 and L2", row: 2, col: 1)
                AppUI.text(&ctx, "(STAT 1:Edit) first.", row: 3, col: 1)
                AppUI.softkeys(&ctx, ["MAIN", "", "", "", ""], size: size)
                return
            }
            let xs = Array(x.prefix(n)), ys = Array(y.prefix(n))
            let xpad = max(1, (xs.max()! - xs.min()!) * 0.1), ypad = max(1, (ys.max()! - ys.min()!) * 0.1)
            Graphing.setWindow(store, xs.min()! - xpad, xs.max()! + xpad, 1, ys.min()! - ypad, ys.max()! + ypad, 1)
            let w = GraphWindow(store: store)
            GraphRenderer.drawGrid(&ctx, size, w, store)
            for (px, py) in zip(xs, ys) {
                ctx.stroke(Path(CGRect(x: w.px(px, size) - 2.5, y: w.py(py, size) - 2.5, width: 5, height: 5)), with: .color(GraphRenderer.color(1)), lineWidth: 1.5)
            }
            if let r = try? Stats.linReg(xs, ys) {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: w.py(r.a * w.xmin + r.b, size))); p.addLine(to: CGPoint(x: size.width, y: w.py(r.a * w.xmax + r.b, size)))
                ctx.stroke(p, with: .color(.red), lineWidth: 1)
                ctx.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: 14)), with: .color(.white.opacity(0.85)))
                ctx.drawText("y=\(AppUI.short(r.a, 4))x+\(AppUI.short(r.b, 4))  r=\(AppUI.short(r.r, 4))", at: CGPoint(x: 2, y: 1), size: 11, weight: .regular, color: .black)
            }
            AppUI.softkeys(&ctx, ["MAIN", "", "", "", ""], size: size)
        case .vector:
            AppUI.text(&ctx, "VECTOR CALCULATOR", row: 0, col: 0, inverted: true)
            let labels = ["V1x", "V1y", "V2x", "V2y"]
            for i in 0..<4 {
                AppUI.text(&ctx, labels[i] + "=", row: 1 + i, col: 0, inverted: vecRow == i)
                AppUI.text(&ctx, vec[i].text + (vecRow == i ? "_" : ""), row: 1 + i, col: 5)
            }
            let v = vec.map { $0.number(store) ?? 0 }
            let m1 = hypot(v[0], v[1]), m2 = hypot(v[2], v[3])
            let a1 = atan2(v[1], v[0]) * 180 / .pi
            AppUI.text(&ctx, "|V1|=\(AppUI.short(m1, 4)) ∠\(AppUI.short(a1, 2))°", row: 5, col: 0)
            AppUI.text(&ctx, "|V2|=\(AppUI.short(m2, 4))", row: 6, col: 0)
            AppUI.text(&ctx, "V1+V2=(\(AppUI.short(v[0] + v[2], 4)),\(AppUI.short(v[1] + v[3], 4)))", row: 7, col: 0)
            AppUI.text(&ctx, "V1·V2=\(AppUI.short(v[0] * v[2] + v[1] * v[3], 4)) V1×V2=\(AppUI.short(v[0] * v[3] - v[1] * v[2], 4))", row: 8, col: 0)
            AppUI.softkeys(&ctx, ["MAIN", "", "", "", ""], size: size)
        }
    }
}
