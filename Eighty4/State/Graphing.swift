import Foundation
import CoreGraphics

enum ZoomKind: Equatable {
    case standard, decimal, square, trig, integer, stat, fit, previous, sto, rcl, zoomIn, zoomOut, quadrant1
}

struct GraphWindow {
    var xmin, xmax, xscl, ymin, ymax, yscl: Double

    init(store: VariableStore) {
        xmin = store.numbers["Xmin"] ?? -10
        xmax = store.numbers["Xmax"] ?? 10
        xscl = store.numbers["Xscl"] ?? 1
        ymin = store.numbers["Ymin"] ?? -10
        ymax = store.numbers["Ymax"] ?? 10
        yscl = store.numbers["Yscl"] ?? 1
    }

    var isValid: Bool { xmax > xmin && ymax > ymin }

    func px(_ x: Double, _ size: CGSize) -> CGFloat { CGFloat((x - xmin) / (xmax - xmin)) * size.width }
    func py(_ y: Double, _ size: CGSize) -> CGFloat { CGFloat((ymax - y) / (ymax - ymin)) * size.height }
    func xAt(column: Int, _ size: CGSize) -> Double { xmin + (xmax - xmin) * Double(column) / Double(max(1, Int(size.width) - 1)) }
}

enum Graphing {
    static let size = CGSize(width: 320, height: 218)
    static let windowKeys = ["Xmin", "Xmax", "Xscl", "Ymin", "Ymax", "Yscl"]

    static func setWindow(_ store: VariableStore, _ xmin: Double, _ xmax: Double, _ xscl: Double, _ ymin: Double, _ ymax: Double, _ yscl: Double) {
        store.numbers["Xmin"] = xmin; store.numbers["Xmax"] = xmax; store.numbers["Xscl"] = xscl
        store.numbers["Ymin"] = ymin; store.numbers["Ymax"] = ymax; store.numbers["Yscl"] = yscl
    }

    private static func snapshot(_ store: VariableStore) -> [String: Double] {
        Dictionary(uniqueKeysWithValues: windowKeys.map { ($0, store.numbers[$0] ?? 0) })
    }

    static func zoom(_ kind: ZoomKind, store: VariableStore, center: (Double, Double)? = nil) {
        let w = GraphWindow(store: store)
        if kind != .previous { store.previousWindow = snapshot(store) }
        switch kind {
        case .standard: setWindow(store, -10, 10, 1, -10, 10, 1)
        case .decimal: setWindow(store, -6.6, 6.6, 1, -4.1, 4.1, 1)
        case .integer: setWindow(store, -47, 47, 10, -31, 31, 10)
        case .quadrant1: setWindow(store, 0, 10, 1, 0, 10, 1)
        case .trig:
            if store.degrees { setWindow(store, -352.5, 352.5, 90, -4, 4, 1) }
            else { setWindow(store, -47 / 24 * .pi, 47 / 24 * .pi, .pi / 2, -4, 4, 1) }
        case .square:
            let yr = w.ymax - w.ymin
            let xr = yr * Double(size.width) / Double(size.height)
            let cx = (w.xmin + w.xmax) / 2
            setWindow(store, cx - xr / 2, cx + xr / 2, w.xscl, w.ymin, w.ymax, w.yscl)
        case .zoomIn, .zoomOut:
            let xf = store.numbers["XFact"] ?? 4, yf = store.numbers["YFact"] ?? 4
            let f = kind == .zoomIn ? 1.0 : -1.0
            let cx = center?.0 ?? (w.xmin + w.xmax) / 2, cy = center?.1 ?? (w.ymin + w.ymax) / 2
            let xr = (w.xmax - w.xmin) * (f > 0 ? 1 / xf : xf), yr = (w.ymax - w.ymin) * (f > 0 ? 1 / yf : yf)
            setWindow(store, cx - xr / 2, cx + xr / 2, w.xscl, cy - yr / 2, cy + yr / 2, w.yscl)
        case .stat:
            var xs: [Double] = [], ys: [Double] = []
            for i in 1...3 where store.plotOn(i) {
                let (lx, ly) = plotLists(store, i)
                xs += lx; ys += ly
            }
            if xs.isEmpty { xs = store.lists["L1"] ?? []; ys = store.lists["L2"] ?? [] }
            guard let xmn = xs.min(), let xmx = xs.max(), let ymn = ys.min(), let ymx = ys.max() else { return }
            let xpad = max(1, (xmx - xmn) * 0.1), ypad = max(1, (ymx - ymn) * 0.1)
            setWindow(store, xmn - xpad, xmx + xpad, w.xscl, ymn - ypad, ymx + ypad, w.yscl)
        case .fit:
            var lo = Double.infinity, hi = -Double.infinity
            for n in 0...9 {
                for col in stride(from: 0, to: Int(size.width), by: 4) {
                    if let y = y(n, at: w.xAt(column: col, size), store: store), y.isFinite { lo = min(lo, y); hi = max(hi, y) }
                }
            }
            if lo.isFinite, hi.isFinite, hi > lo { setWindow(store, w.xmin, w.xmax, w.xscl, lo, hi, w.yscl) }
        case .previous:
            for (k, v) in store.previousWindow { store.numbers[k] = v }
        case .sto:
            store.storedWindow = snapshot(store)
        case .rcl:
            for (k, v) in store.storedWindow { store.numbers[k] = v }
        }
    }

    static func plotLists(_ store: VariableStore, _ i: Int) -> ([Double], [Double]) {
        let x = "L\(store.options["plot\(i)X", default: 0] + 1)", y = "L\(store.options["plot\(i)Y", default: 1] + 1)"
        let lx = store.lists[x] ?? [], ly = store.lists[y] ?? []
        let n = min(lx.count, ly.count)
        return (Array(lx.prefix(n)), Array(ly.prefix(n)))
    }

    /// Evaluates Yn at x. Returns nil for undefined / errors / disabled functions.
    static func y(_ n: Int, at x: Double, store: VariableStore) -> Double? {
        guard let text = store.yFuncs[n], !text.isEmpty, store.isYEnabled(n) else { return nil }
        let old = store.xOverride
        store.xOverride = x
        defer { store.xOverride = old }
        guard let v = try? Evaluator.evaluate(text, ctx: EvalContext(store: store)), let d = v.asDouble, d.isFinite else { return nil }
        return d
    }

    static func evaluate(_ text: String, at x: Double, store: VariableStore) -> Double? {
        let old = store.xOverride
        store.xOverride = x
        defer { store.xOverride = old }
        guard let v = try? Evaluator.evaluate(text, ctx: EvalContext(store: store)), let d = v.asDouble, d.isFinite else { return nil }
        return d
    }

    static func definedFunctions(_ store: VariableStore) -> [Int] {
        let order = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]
        return order.filter { !(store.yFuncs[$0] ?? "").isEmpty && store.isYEnabled($0) }
    }

    static func samples(_ store: VariableStore) -> [Int: [CGPoint?]] {
        let w = GraphWindow(store: store)
        guard w.isValid else { return [:] }
        var out: [Int: [CGPoint?]] = [:]
        let cols = Int(size.width)
        for n in definedFunctions(store) {
            var pts: [CGPoint?] = []
            pts.reserveCapacity(cols)
            for col in 0..<cols {
                let x = w.xAt(column: col, size)
                if let y = y(n, at: x, store: store) {
                    let py = w.py(y, size)
                    pts.append(abs(py) < 5000 ? CGPoint(x: CGFloat(col), y: py) : nil)
                } else {
                    pts.append(nil)
                }
            }
            out[n] = pts
        }
        return out
    }

    static func functionColor(_ n: Int) -> (Double, Double, Double) {
        switch n {
        case 1: return (0.05, 0.35, 0.85)
        case 2: return (0.85, 0.1, 0.1)
        case 3: return (0, 0, 0)
        case 4: return (0.8, 0.1, 0.7)
        case 5: return (0.1, 0.6, 0.15)
        case 6: return (0.95, 0.5, 0.05)
        case 7: return (0.5, 0.3, 0.1)
        case 8: return (0.05, 0.1, 0.5)
        case 9: return (0.3, 0.6, 0.9)
        default: return (0.5, 0.5, 0.5)
        }
    }

    // MARK: - CALC operations

    static func zero(_ n: Int, _ lo: Double, _ hi: Double, store: VariableStore) throws -> Double {
        guard let flo = y(n, at: lo, store: store), let fhi = y(n, at: hi, store: store) else { throw CalcError.undefined }
        if flo == 0 { return lo }
        if fhi == 0 { return hi }
        guard (flo < 0) != (fhi < 0) else { throw CalcError.noSignChange }
        return Stats.bisect({ y(n, at: $0, store: store) ?? 0 }, lo, hi)
    }

    static func extremum(_ n: Int, _ lo: Double, _ hi: Double, isMax: Bool, store: VariableStore) throws -> Double {
        var a = lo, b = hi
        let phi = (sqrt(5.0) - 1) / 2
        let s: Double = isMax ? -1 : 1
        func f(_ x: Double) throws -> Double { guard let v = y(n, at: x, store: store) else { throw CalcError.undefined }; return s * v }
        var c = b - phi * (b - a), d = a + phi * (b - a)
        var fc = try f(c), fd = try f(d)
        for _ in 0..<150 {
            if fc < fd { b = d; d = c; fd = fc; c = b - phi * (b - a); fc = try f(c) }
            else { a = c; c = d; fc = fd; d = a + phi * (b - a); fd = try f(d) }
        }
        return (a + b) / 2
    }

    static func intersect(_ n1: Int, _ n2: Int, guess: Double, store: VariableStore) throws -> Double {
        let w = GraphWindow(store: store)
        let step = (w.xmax - w.xmin) / 400
        func diff(_ x: Double) -> Double? {
            guard let a = y(n1, at: x, store: store), let b = y(n2, at: x, store: store) else { return nil }
            return a - b
        }
        // Scan outward from the guess for the nearest sign change.
        for k in 0..<400 {
            for dir in [1.0, -1.0] {
                let x0 = guess + dir * Double(k) * step, x1 = x0 + dir * step
                guard let d0 = diff(x0), let d1 = diff(x1) else { continue }
                if d0 == 0 { return x0 }
                if (d0 < 0) != (d1 < 0) { return Stats.bisect({ diff($0) ?? 0 }, min(x0, x1), max(x0, x1)) }
            }
        }
        throw CalcError.noSignChange
    }

    static func derivative(_ n: Int, at x: Double, store: VariableStore) throws -> Double {
        let h = 0.001
        guard let a = y(n, at: x + h, store: store), let b = y(n, at: x - h, store: store) else { throw CalcError.undefined }
        return (a - b) / (2 * h)
    }

    static func integral(_ n: Int, _ lo: Double, _ hi: Double, store: VariableStore) throws -> Double {
        let steps = 1000
        let h = (hi - lo) / Double(steps)
        func f(_ x: Double) throws -> Double { guard let v = y(n, at: x, store: store) else { throw CalcError.undefined }; return v }
        var sum = try f(lo) + (try f(hi))
        for i in 1..<steps { sum += (i % 2 == 0 ? 2 : 4) * (try f(lo + Double(i) * h)) }
        return sum * h / 3
    }
}
