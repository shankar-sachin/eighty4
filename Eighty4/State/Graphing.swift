import Foundation
import CoreGraphics

enum ZoomKind: Equatable {
    case standard, decimal, square, trig, integer, stat, fit, previous, sto, rcl, zoomIn, zoomOut, quadrant1
    case frac(Int)
    case box(Double, Double, Double, Double)
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
    func yAt(row: Double, _ size: CGSize) -> Double { ymax - (ymax - ymin) * row / Double(size.height) }
    func xAt(col: Double, _ size: CGSize) -> Double { xmin + (xmax - xmin) * col / Double(size.width) }
}

enum Graphing {
    static let size = CGSize(width: 320, height: 218)
    /// TI-84 Plus CE graph area in pixels, for Pxl-On( / pxl-Test( coordinates.
    static let tiPixels = CGSize(width: 265, height: 165)
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
        case .frac(let n):
            let d = Double(max(2, n))
            let xr: Double = 66.0 / d
            let yr: Double = 41.0 / d
            setWindow(store, -xr, xr, 1, -yr, yr, 1)
        case .box(let x1, let y1, let x2, let y2):
            guard x1 != x2, y1 != y2 else { return }
            setWindow(store, min(x1, x2), max(x1, x2), w.xscl, min(y1, y2), max(y1, y2), w.yscl)
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
            var xlo = Double.infinity, xhi = -Double.infinity
            for n in definedFunctions(store) {
                if store.graphType == .function {
                    for col in stride(from: 0, to: Int(size.width), by: 4) {
                        if let y = y(n, at: w.xAt(column: col, size), store: store), y.isFinite { lo = min(lo, y); hi = max(hi, y) }
                    }
                } else {
                    for p in parameterValues(store) {
                        if let (x, y) = point(n, at: p, store: store) { lo = min(lo, y); hi = max(hi, y); xlo = min(xlo, x); xhi = max(xhi, x) }
                    }
                }
            }
            if lo.isFinite, hi.isFinite, hi > lo {
                if store.graphType == .function || !(xlo.isFinite && xhi > xlo) { setWindow(store, w.xmin, w.xmax, w.xscl, lo, hi, w.yscl) }
                else { setWindow(store, xlo, xhi, w.xscl, lo, hi, w.yscl) }
            }
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

    // MARK: - Evaluation in every graph mode

    /// Evaluates Yn at x. Returns nil for undefined / errors / disabled functions.
    static func y(_ n: Int, at x: Double, store: VariableStore) -> Double? {
        guard let text = store.yFuncs[n], !text.isEmpty, store.isYEnabled(n) else { return nil }
        return evaluate(text, at: x, store: store)
    }

    static func evaluate(_ text: String, at x: Double, store: VariableStore) -> Double? {
        evaluate(text, with: ["X": x], store: store)
    }

    static func evaluate(_ text: String, with vars: [String: Double], store: VariableStore) -> Double? {
        let old = store.overrides
        for (k, v) in vars { store.overrides[k] = v }
        defer { store.overrides = old }
        guard let v = try? Evaluator.evaluate(text, ctx: EvalContext(store: store)), let d = v.asDouble, d.isFinite else { return nil }
        return d
    }

    /// Function keys drawn for index n in the current mode.
    static func keys(for n: Int, _ store: VariableStore) -> [String] {
        switch store.graphType {
        case .function: return ["Y\(n)"]
        case .parametric: return ["X\(n)T", "Y\(n)T"]
        case .polar: return ["r\(n)"]
        case .sequence: return [Sequences.names[max(0, min(2, n - 1))]]
        }
    }

    static func definedFunctions(_ store: VariableStore) -> [Int] {
        switch store.graphType {
        case .function:
            return [1, 2, 3, 4, 5, 6, 7, 8, 9, 0].filter { !(store.yFuncs[$0] ?? "").isEmpty && store.isYEnabled($0) }
        case .parametric:
            return (1...6).filter { !(store.funcs["X\($0)T"] ?? "").isEmpty && !(store.funcs["Y\($0)T"] ?? "").isEmpty && store.funcEnabled("X\($0)T") }
        case .polar:
            return (1...6).filter { !(store.funcs["r\($0)"] ?? "").isEmpty && store.funcEnabled("r\($0)") }
        case .sequence:
            return (1...3).filter { !(store.funcs[Sequences.names[$0 - 1]] ?? "").isEmpty && store.funcEnabled(Sequences.names[$0 - 1]) }
        }
    }

    /// Name of the independent variable in the current mode.
    static func parameterName(_ store: VariableStore) -> String {
        switch store.graphType {
        case .function: return "X"
        case .parametric: return "T"
        case .polar: return "θ"
        case .sequence: return "n"
        }
    }

    /// (min, max, step) of the parameter in non-function modes.
    static func parameterRange(_ store: VariableStore) -> (Double, Double, Double) {
        switch store.graphType {
        case .function:
            let w = GraphWindow(store: store)
            return (w.xmin, w.xmax, (w.xmax - w.xmin) / Double(Int(size.width) - 1))
        case .parametric: return (store.numbers["Tmin"] ?? 0, store.numbers["Tmax"] ?? 2 * .pi, store.numbers["Tstep"] ?? .pi / 24)
        case .polar: return (store.numbers["θmin"] ?? 0, store.numbers["θmax"] ?? 2 * .pi, store.numbers["θstep"] ?? .pi / 24)
        case .sequence: return (store.numbers["PlotStart"] ?? 1, store.numbers["nMax"] ?? 10, store.numbers["PlotStep"] ?? 1)
        }
    }

    static func parameterValues(_ store: VariableStore) -> [Double] {
        let (lo, hi, step) = parameterRange(store)
        guard step > 0, hi >= lo else { return [] }
        var out: [Double] = []
        var p = lo
        while p <= hi + 1e-9 && out.count < 5000 { out.append(p); p += step }
        return out
    }

    /// Point (x, y) for function n at parameter value p in the current mode.
    static func point(_ n: Int, at p: Double, store: VariableStore) -> (Double, Double)? {
        switch store.graphType {
        case .function:
            guard let yv = y(n, at: p, store: store) else { return nil }
            return (p, yv)
        case .parametric:
            guard let xt = store.funcs["X\(n)T"], let yt = store.funcs["Y\(n)T"], store.funcEnabled("X\(n)T"),
                  let x = evaluate(xt, with: ["T": p], store: store), let y = evaluate(yt, with: ["T": p], store: store) else { return nil }
            return (x, y)
        case .polar:
            guard let rt = store.funcs["r\(n)"], store.funcEnabled("r\(n)"),
                  let r = evaluate(rt, with: ["θ": p], store: store) else { return nil }
            let a = store.degrees ? p * .pi / 180 : p
            return (r * cos(a), r * sin(a))
        case .sequence:
            let name = Sequences.names[max(0, min(2, n - 1))]
            guard store.funcEnabled(name), let v = try? Sequences.value(name, n: Int(p.rounded()), store: store, depth: 0), v.isFinite else { return nil }
            return (p.rounded(), v)
        }
    }

    static func samples(_ store: VariableStore) -> [Int: [CGPoint?]] {
        let w = GraphWindow(store: store)
        guard w.isValid else { return [:] }
        var out: [Int: [CGPoint?]] = [:]
        if store.graphType == .function {
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
        let params = parameterValues(store)
        for n in definedFunctions(store) {
            out[n] = params.map { p in
                guard let (x, y) = point(n, at: p, store: store) else { return nil }
                let px = w.px(x, size), py = w.py(y, size)
                return (abs(px) < 5000 && abs(py) < 5000) ? CGPoint(x: px, y: py) : nil
            }
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

    /// BackgroundOn color codes (TI 10…24).
    static func backgroundColor(_ code: Int) -> (Double, Double, Double)? {
        switch code {
        case 10: return (0.55, 0.7, 1.0)
        case 11: return (1.0, 0.6, 0.6)
        case 12: return (0.35, 0.35, 0.35)
        case 13: return (1.0, 0.6, 0.9)
        case 14: return (0.6, 0.9, 0.6)
        case 15: return (1.0, 0.8, 0.5)
        case 16: return (0.75, 0.6, 0.45)
        case 17: return (0.5, 0.55, 0.8)
        case 18: return (0.75, 0.9, 1.0)
        case 19: return (1.0, 1.0, 0.6)
        case 20: return (1, 1, 1)
        case 21: return (0.85, 0.85, 0.85)
        case 22: return (0.7, 0.7, 0.7)
        case 23: return (0.55, 0.55, 0.55)
        case 24: return (0.4, 0.4, 0.4)
        default: return nil
        }
    }

    // MARK: - CALC operations

    /// TI-84 Evo Points of Interest trace: the y-intercept, zero, extremum or intersection that the trace
    /// cursor just stepped over between `x0` and `x1` (strictly inside, so a cursor sitting on one moves on).
    struct PointOfInterest: Equatable { let label: String; let x: Double; let y: Double }

    static func pointOfInterest(_ n: Int, from x0: Double, to x1: Double, store: VariableStore) -> PointOfInterest? {
        let lo = min(x0, x1), hi = max(x0, x1)
        guard lo < hi, store.graphType == .function,
              let y0 = y(n, at: lo, store: store), let y1 = y(n, at: hi, store: store), y0.isFinite, y1.isFinite else { return nil }
        if lo < 0, 0 < hi, let yy = y(n, at: 0, store: store), yy.isFinite { return PointOfInterest(label: "Y-intercept", x: 0, y: yy) }
        if y0 * y1 < 0, let z = try? zero(n, lo, hi, store: store) { return PointOfInterest(label: "Zero", x: z, y: 0) }
        if let d0 = try? derivative(n, at: lo, store: store), let d1 = try? derivative(n, at: hi, store: store), d0 * d1 < 0,
           let ex = try? extremum(n, lo, hi, isMax: d0 > 0, store: store), let ey = y(n, at: ex, store: store) {
            return PointOfInterest(label: d0 > 0 ? "Maximum" : "Minimum", x: ex, y: ey)
        }
        for m in definedFunctions(store) where m != n {
            guard let m0 = y(m, at: lo, store: store), let m1 = y(m, at: hi, store: store), (y0 - m0) * (y1 - m1) < 0,
                  let ix = try? intersect(n, m, guess: (lo + hi) / 2, store: store), ix > lo, ix < hi, let iy = y(n, at: ix, store: store) else { continue }
            return PointOfInterest(label: "Intersection", x: ix, y: iy)
        }
        return nil
    }

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
        if store.graphType != .function {
            let h = 1e-4
            guard let (x1, y1) = point(n, at: x + h, store: store), let (x0, y0) = point(n, at: x - h, store: store), x1 != x0 else { throw CalcError.undefined }
            return (y1 - y0) / (x1 - x0)
        }
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
