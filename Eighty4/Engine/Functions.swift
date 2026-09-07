import Foundation

struct FunctionDef {
    let minArgs: Int
    let maxArgs: Int
    let body: ([Value], EvalContext) throws -> Value
}

/// Every built-in function the menus can insert. Names are stored without the "(".
enum Functions {
    static let lazyNames: Set<String> = ["seq", "fMin", "fMax", "nDeriv", "fnInt", "Σ",
                                         "Fill", "Matr▶list", "List▶matr", "Tangent", "Shade", "expr", "eval", "piecewise"]

    static var allNames: [String] { Array(table.keys) + Array(lazyNames) }

    static func call(_ name: String, _ args: [Value], _ ctx: EvalContext) throws -> Value {
        guard let f = table[name] else { throw CalcError.syntax }
        guard args.count >= f.minArgs, args.count <= f.maxArgs else { throw CalcError.argument }
        return try f.body(args, ctx)
    }

    // MARK: - Helpers

    private static func n(_ v: Value) throws -> Double { try v.number() }
    private static func l(_ v: Value) throws -> [Double] {
        if case .list(let x) = v { return x }
        return [try v.number()]
    }
    private static func m(_ v: Value) throws -> [[Double]] { try v.matrixValue() }
    /// Rows of a complex matrix, or nil for anything else (real matrices keep their fast path).
    private static func cm(_ v: Value) -> [[Cx]]? {
        if case .cmatrix(let rows) = v { return rows }
        return nil
    }
    private static func cxv(_ z: Cx) -> Value { Value.cx(z.re, z.im) }
    /// Elements of a complex list, or nil for anything else (real lists keep their fast path).
    private static func cl(_ v: Value) -> [(Double, Double)]? {
        if case .clist = v { return v.asComplexElements }
        return nil
    }
    private static func cxFold(_ op: BinaryOp, _ xs: [(Double, Double)], start: (Double, Double)) throws -> Value {
        var acc: Value = Value.cx(start.0, start.1)
        for x in xs { acc = try ComplexMath.apply(op, acc.asComplex ?? (0, 0), x) }
        return acc
    }
    private static func toRad(_ x: Double, _ ctx: EvalContext) -> Double { ctx.store.degrees ? x * .pi / 180 : x }
    private static func fromRad(_ x: Double, _ ctx: EvalContext) -> Double { ctx.store.degrees ? x * 180 / .pi : x }

    private static func unary(_ f: @escaping (Double) throws -> Double) -> FunctionDef {
        FunctionDef(minArgs: 1, maxArgs: 1) { args, _ in try args[0].mapNumbers(f) }
    }

    static let table: [String: FunctionDef] = build()

    private static func build() -> [String: FunctionDef] {
        var t: [String: FunctionDef] = [:]
        func reg(_ name: String, _ minA: Int, _ maxA: Int, _ body: @escaping ([Value], EvalContext) throws -> Value) {
            t[name] = FunctionDef(minArgs: minA, maxArgs: maxA, body: body)
        }

        // Trig (angle mode aware)
        reg("sin", 1, 1) { a, c in try a[0].mapNumbers { sin(toRad($0, c)) } }
        reg("cos", 1, 1) { a, c in try a[0].mapNumbers { cos(toRad($0, c)) } }
        reg("tan", 1, 1) { a, c in try a[0].mapNumbers { tan(toRad($0, c)) } }
        reg("sin⁻¹", 1, 1) { a, c in try a[0].mapNumbers { if abs($0) > 1 { throw CalcError.domain }; return fromRad(asin($0), c) } }
        reg("cos⁻¹", 1, 1) { a, c in try a[0].mapNumbers { if abs($0) > 1 { throw CalcError.domain }; return fromRad(acos($0), c) } }
        reg("tan⁻¹", 1, 1) { a, c in try a[0].mapNumbers { fromRad(atan($0), c) } }
        t["sinh"] = unary { sinh($0) }
        t["cosh"] = unary { cosh($0) }
        t["tanh"] = unary { tanh($0) }
        t["sinh⁻¹"] = unary { asinh($0) }
        t["cosh⁻¹"] = unary { if $0 < 1 { throw CalcError.domain }; return acosh($0) }
        t["tanh⁻¹"] = unary { if abs($0) >= 1 { throw CalcError.domain }; return atanh($0) }

        // Logs, roots. Negative arguments are complex-valued: allowed in a+bi / re^θi mode, ERR:NONREAL ANS in REAL.
        func complexLn(_ v: Value) throws -> Value? {
            if v.isComplex, let z = v.asComplex { let r = try ComplexMath.ln(z); return Value.cx(r.0, r.1) }
            if let x = v.asDouble, x < 0 {
                guard Value.complexResults else { throw CalcError.nonrealAns }
                return Value.cx(log(-x), .pi)
            }
            return nil
        }
        reg("log", 1, 2) { a, _ in
            if a.count == 2 {
                let x = try n(a[0]), b = try n(a[1])
                if x <= 0 || b <= 0 || b == 1 { throw CalcError.domain }
                return .num(log(x) / log(b))
            }
            if let c = try complexLn(a[0]) { return try Value.apply(.div, c, .num(log(10))) }
            return try a[0].mapNumbers { if $0 <= 0 { throw CalcError.domain }; return log10($0) }
        }
        reg("ln", 1, 1) { a, _ in
            if let c = try complexLn(a[0]) { return c }
            return try a[0].mapNumbers { if $0 <= 0 { throw CalcError.domain }; return log($0) }
        }
        reg("√", 1, 1) { a, _ in
            if a[0].isComplex, let z = a[0].asComplex { let r = ComplexMath.sqrt(z); return Value.cx(r.0, r.1) }
            if let x = a[0].asDouble, x < 0 {
                guard Value.complexResults else { throw CalcError.nonrealAns }
                return Value.cx(0, (-x).squareRoot())
            }
            return try a[0].mapNumbers { if $0 < 0 { throw CalcError.nonrealAns }; return $0.squareRoot() }
        }
        reg("logBASE", 2, 2) { a, _ in
            let x = try n(a[0]), b = try n(a[1])
            if x <= 0 || b <= 0 || b == 1 { throw CalcError.domain }
            return .num(log(x) / log(b))
        }
        t["³√"] = unary { cbrt($0) }
        reg("abs", 1, 1) { a, _ in
            if a[0].isComplex, let z = a[0].asComplex { return .num(ComplexMath.abs(z)) }
            if let xs = cl(a[0]) { return .list(xs.map { ComplexMath.abs($0) }) }
            if case .matrix(let mm) = a[0] { return .matrix(mm.map { $0.map { abs($0) } }) }
            if let mm = cm(a[0]) { return .matrix(mm.map { $0.map(\.magnitude) }) }
            return try a[0].mapNumbers { abs($0) }
        }

        // NUM
        reg("round", 1, 2) { a, _ in
            let d = a.count == 2 ? Int(try n(a[1])) : 9
            let p = pow(10.0, Double(max(0, min(9, d))))
            return try a[0].mapNumbers { ($0 * p).rounded() / p }
        }
        t["iPart"] = unary { $0 < 0 ? ceil($0) : floor($0) }
        t["fPart"] = unary { $0 - ($0 < 0 ? ceil($0) : floor($0)) }
        t["int"] = unary { floor($0) }
        reg("min", 1, 2) { a, _ in
            if a.count == 1 { let x = try l(a[0]); guard let v = x.min() else { throw CalcError.argument }; return .num(v) }
            return try Value.apply(.lt, a[0], a[1]) == .num(1) ? a[0] : a[1]
        }
        reg("max", 1, 2) { a, _ in
            if a.count == 1 { let x = try l(a[0]); guard let v = x.max() else { throw CalcError.argument }; return .num(v) }
            return try Value.apply(.gt, a[0], a[1]) == .num(1) ? a[0] : a[1]
        }
        reg("gcd", 2, 2) { a, _ in .num(Double(Stats.gcd(Int(try n(a[0])), Int(try n(a[1]))))) }
        reg("lcm", 2, 2) { a, _ in
            let x = Int(try n(a[0])), y = Int(try n(a[1]))
            let g = Stats.gcd(x, y)
            return .num(g == 0 ? 0 : Double(abs(x * y) / g))
        }
        reg("remainder", 2, 2) { a, _ in
            let x = try n(a[0]), y = try n(a[1])
            if y == 0 { throw CalcError.divideByZero }
            return .num(x.truncatingRemainder(dividingBy: y))
        }

        // CMPLX
        func z(_ v: Value) throws -> (Double, Double) {
            guard let c = v.asComplex else { throw CalcError.dataType }
            return c
        }
        reg("conj", 1, 1) { a, _ in
            if let xs = cl(a[0]) { return Value.fromComplexElements(xs.map { ($0.0, -$0.1) }) }
            if let mm = cm(a[0]) { return Value.fromComplexRows(mm.map { $0.map { Cx(re: $0.re, im: -$0.im) } }) }
            if case .matrix = a[0] { return a[0] }
            let c = try z(a[0]); return Value.cx(c.0, -c.1)
        }
        reg("real", 1, 1) { a, _ in
            if let xs = cl(a[0]) { return .list(xs.map { $0.0 }) }
            if let mm = cm(a[0]) { return .matrix(mm.map { $0.map(\.re) }) }
            if case .matrix = a[0] { return a[0] }
            return .num(try z(a[0]).0)
        }
        reg("imag", 1, 1) { a, _ in
            if let xs = cl(a[0]) { return .list(xs.map { $0.1 }) }
            if let mm = cm(a[0]) { return .matrix(mm.map { $0.map(\.im) }) }
            if case .matrix(let mm) = a[0] { return .matrix(mm.map { $0.map { _ in 0 } }) }
            return .num(try z(a[0]).1)
        }
        reg("angle", 1, 1) { a, c in
            if let xs = cl(a[0]) { return .list(xs.map { fromRad(ComplexMath.angle($0), c) }) }
            return .num(fromRad(ComplexMath.angle(try z(a[0])), c))
        }

        // OS 5.x additions
        reg("toString", 1, 1) { a, c in .str(ResultFormatter.format(a[0], store: c.store)) }
        reg("invBinom", 3, 3) { a, _ in
            let area = try n(a[0]), trials = try n(a[1]), p = try n(a[2])
            guard area >= 0, area <= 1, trials >= 0, p >= 0, p <= 1 else { throw CalcError.domain }
            var cum = 0.0
            for x in 0...max(0, Int(trials)) {
                cum += Stats.binomPDF(trials, p, Double(x))
                if cum >= area - 1e-12 { return .num(Double(x)) }
            }
            return .num(trials)
        }

        // PROB
        reg("rand", 0, 1) { a, _ in
            if a.count == 1 { return .list((0..<max(0, Int(try n(a[0])))).map { _ in Double.random(in: 0..<1) }) }
            return .num(Double.random(in: 0..<1))
        }
        reg("randInt", 2, 3) { a, _ in
            let lo = Int(try n(a[0])), hi = Int(try n(a[1]))
            guard lo <= hi else { throw CalcError.argument }
            if a.count == 3 { return .list((0..<max(0, Int(try n(a[2])))).map { _ in Double(Int.random(in: lo...hi)) }) }
            return .num(Double(Int.random(in: lo...hi)))
        }
        reg("randNorm", 2, 3) { a, _ in
            let mu = try n(a[0]), sd = try n(a[1])
            func one() -> Double { mu + sd * Stats.gaussian() }
            if a.count == 3 { return .list((0..<max(0, Int(try n(a[2])))).map { _ in one() }) }
            return .num(one())
        }
        reg("randBin", 2, 3) { a, _ in
            let trials = Int(try n(a[0])), p = try n(a[1])
            func one() -> Double { Double((0..<max(0, trials)).filter { _ in Double.random(in: 0..<1) < p }.count) }
            if a.count == 3 { return .list((0..<max(0, Int(try n(a[2])))).map { _ in one() }) }
            return .num(one())
        }
        reg("randIntNoRep", 2, 2) { a, _ in
            let lo = Int(try n(a[0])), hi = Int(try n(a[1]))
            guard lo <= hi else { throw CalcError.argument }
            return .list(Array(lo...hi).shuffled().map(Double.init))
        }
        reg("not", 1, 1) { a, _ in try a[0].mapNumbers { $0 == 0 ? 1 : 0 } }

        // LIST
        reg("sum", 1, 1) { a, _ in
            if let xs = cl(a[0]) { return try cxFold(.add, xs, start: (0, 0)) }
            return .num(try l(a[0]).reduce(0, +))
        }
        reg("prod", 1, 1) { a, _ in
            if let xs = cl(a[0]) { return try cxFold(.mul, xs, start: (1, 0)) }
            return .num(try l(a[0]).reduce(1, *))
        }
        reg("mean", 1, 1) { a, _ in
            if let xs = cl(a[0]) { return try Value.apply(.div, try cxFold(.add, xs, start: (0, 0)), .num(Double(xs.count))) }
            let x = try l(a[0]); guard !x.isEmpty else { throw CalcError.argument }; return .num(x.reduce(0, +) / Double(x.count))
        }
        reg("median", 1, 1) { a, _ in .num(try Stats.median(try l(a[0]))) }
        reg("stdDev", 1, 1) { a, _ in .num(try Stats.stdDev(try l(a[0]), sample: true)) }
        reg("variance", 1, 1) { a, _ in let s = try Stats.stdDev(try l(a[0]), sample: true); return .num(s * s) }
        reg("cumSum", 1, 1) { a, _ in
            if case .matrix(let mm) = a[0] {
                var out = mm
                for r in 1..<max(1, mm.count) { for c in 0..<mm[r].count { out[r][c] = out[r - 1][c] + mm[r][c] } }
                return .matrix(out)
            }
            if let mm = cm(a[0]) {
                var out = mm
                for r in 1..<max(1, mm.count) { for c in 0..<mm[r].count { out[r][c] = out[r - 1][c] + mm[r][c] } }
                return .cmatrix(out)
            }
            if let xs = cl(a[0]) {
                var acc: (Double, Double) = (0, 0)
                return Value.fromComplexElements(xs.map { acc = (acc.0 + $0.0, acc.1 + $0.1); return acc })
            }
            var acc = 0.0
            return .list(try l(a[0]).map { acc += $0; return acc })
        }
        reg("ΔList", 1, 1) { a, _ in let x = try l(a[0]); return .list(zip(x.dropFirst(), x).map { $0 - $1 }) }
        reg("dim", 1, 1) { a, _ in
            if let mm = a[0].asComplexRows { let (r, c) = Matrix.dims(mm); return .list([Double(r), Double(c)]) }
            if let xs = cl(a[0]) { return .num(Double(xs.count)) }
            return .num(Double(try a[0].listValue().count))
        }
        reg("augment", 2, 2) { a, _ in
            if a[0].isAnyMatrix || a[1].isAnyMatrix {
                guard let x = a[0].asComplexRows, let y = a[1].asComplexRows else { throw CalcError.dataType }
                guard x.count == y.count else { throw CalcError.dimMismatch }
                return Value.fromComplexRows(zip(x, y).map { $0 + $1 })
            }
            if a[0].isComplexList || a[1].isComplexList {
                guard let x = a[0].asComplexElements, let y = a[1].asComplexElements else { throw CalcError.dataType }
                return Value.fromComplexElements(x + y)
            }
            return .list(try a[0].listValue() + a[1].listValue())
        }
        reg("SortA", 1, 1) { a, _ in .list(try l(a[0]).sorted()) }
        reg("SortD", 1, 1) { a, _ in .list(try l(a[0]).sorted(by: >)) }
        reg("sortA", 1, 1) { a, _ in .list(try l(a[0]).sorted()) }
        reg("sortD", 1, 1) { a, _ in .list(try l(a[0]).sorted(by: >)) }

        // MATRIX
        reg("det", 1, 1) { a, _ in
            if let mm = cm(a[0]) { return cxv(try Matrix.det(mm)) }
            return .num(try Matrix.det(try m(a[0])))
        }
        reg("identity", 1, 1) { a, _ in
            let k = Int(try n(a[0])); guard k >= 1, k <= 20 else { throw CalcError.invalidDim }
            let id: [[Double]] = Matrix.identity(k)
            return .matrix(id)
        }
        reg("randM", 2, 2) { a, _ in
            let r = Int(try n(a[0])), c = Int(try n(a[1]))
            guard r >= 1, c >= 1, r <= 20, c <= 20 else { throw CalcError.invalidDim }
            return .matrix((0..<r).map { _ in (0..<c).map { _ in Double(Int.random(in: -9...9)) } })
        }
        reg("ref", 1, 1) { a, _ in
            if let mm = cm(a[0]) { return Value.fromComplexRows(Matrix.ref(mm)) }
            return .matrix(Matrix.ref(try m(a[0])))
        }
        reg("rref", 1, 1) { a, _ in
            if let mm = cm(a[0]) { return Value.fromComplexRows(Matrix.rref(mm)) }
            return .matrix(Matrix.rref(try m(a[0])))
        }

        // ANGLE
        reg("R▶Pr", 2, 2) { a, _ in .num(hypot(try n(a[0]), try n(a[1]))) }
        reg("R▶Pθ", 2, 2) { a, c in .num(fromRad(atan2(try n(a[1]), try n(a[0])), c)) }
        reg("P▶Rx", 2, 2) { a, c in .num(try n(a[0]) * cos(toRad(try n(a[1]), c))) }
        reg("P▶Ry", 2, 2) { a, c in .num(try n(a[0]) * sin(toRad(try n(a[1]), c))) }

        // DISTR
        reg("normalpdf", 1, 3) { a, _ in
            let mu = a.count > 1 ? try n(a[1]) : 0, sd = a.count > 2 ? try n(a[2]) : 1
            return try a[0].mapNumbers { Stats.normalPDF($0, mu, sd) }
        }
        reg("normalcdf", 2, 4) { a, _ in
            let mu = a.count > 2 ? try n(a[2]) : 0, sd = a.count > 3 ? try n(a[3]) : 1
            return .num(Stats.normalCDF(try n(a[0]), try n(a[1]), mu, sd))
        }
        reg("invNorm", 1, 3) { a, _ in
            let p = try n(a[0]); guard p > 0, p < 1 else { throw CalcError.domain }
            let mu = a.count > 1 ? try n(a[1]) : 0, sd = a.count > 2 ? try n(a[2]) : 1
            return .num(mu + sd * Stats.invNorm(p))
        }
        reg("tpdf", 2, 2) { a, _ in .num(Stats.tPDF(try n(a[0]), try n(a[1]))) }
        reg("tcdf", 3, 3) { a, _ in let df = try n(a[2]); return .num(Stats.integrate({ Stats.tPDF($0, df) }, try n(a[0]), try n(a[1]), clamp: 200)) }
        reg("invT", 2, 2) { a, _ in
            let p = try n(a[0]), df = try n(a[1]); guard p > 0, p < 1 else { throw CalcError.domain }
            return .num(Stats.bisect({ Stats.integrate({ Stats.tPDF($0, df) }, -200, $0, clamp: 200) - p }, -200, 200))
        }
        reg("χ²pdf", 2, 2) { a, _ in .num(Stats.chi2PDF(try n(a[0]), try n(a[1]))) }
        reg("χ²cdf", 3, 3) { a, _ in let df = try n(a[2]); return .num(Stats.integrate({ Stats.chi2PDF($0, df) }, max(0, try n(a[0])), try n(a[1]), clamp: 2000)) }
        reg("Fpdf", 3, 3) { a, _ in .num(Stats.fPDF(try n(a[0]), try n(a[1]), try n(a[2]))) }
        reg("Fcdf", 4, 4) { a, _ in let d1 = try n(a[2]), d2 = try n(a[3]); return .num(Stats.integrate({ Stats.fPDF($0, d1, d2) }, max(0, try n(a[0])), try n(a[1]), clamp: 2000)) }
        reg("binompdf", 2, 3) { a, _ in
            let trials = try n(a[0]), p = try n(a[1])
            if a.count == 3 { return try a[2].mapNumbers { Stats.binomPDF(trials, p, $0) } }
            return .list((0...max(0, Int(trials))).map { Stats.binomPDF(trials, p, Double($0)) })
        }
        reg("binomcdf", 2, 3) { a, _ in
            let trials = try n(a[0]), p = try n(a[1])
            func cdf(_ x: Double) -> Double { (0...max(0, Int(x))).reduce(0) { $0 + Stats.binomPDF(trials, p, Double($1)) } }
            if a.count == 3 { return try a[2].mapNumbers { cdf($0) } }
            return .list((0...max(0, Int(trials))).map { cdf(Double($0)) })
        }
        reg("poissonpdf", 2, 2) { a, _ in let mu = try n(a[0]); return try a[1].mapNumbers { Stats.poissonPDF(mu, $0) } }
        reg("poissoncdf", 2, 2) { a, _ in
            let mu = try n(a[0])
            return try a[1].mapNumbers { x in (0...max(0, Int(x))).reduce(0) { $0 + Stats.poissonPDF(mu, Double($1)) } }
        }
        reg("geometpdf", 2, 2) { a, _ in let p = try n(a[0]); return try a[1].mapNumbers { pow(1 - p, $0 - 1) * p } }
        reg("geometcdf", 2, 2) { a, _ in let p = try n(a[0]); return try a[1].mapNumbers { 1 - pow(1 - p, $0) } }

        // DRAW (these record drawings on the graph screen)
        reg("Line", 4, 4) { a, c in
            c.store.drawings.append(.line(try n(a[0]), try n(a[1]), try n(a[2]), try n(a[3])))
            c.store.pendingShowGraph = true
            return .str("Done")
        }
        reg("Circle", 3, 3) { a, c in
            c.store.drawings.append(.circle(try n(a[0]), try n(a[1]), try n(a[2])))
            c.store.pendingShowGraph = true
            return .str("Done")
        }
        reg("Pt-On", 2, 2) { a, c in
            c.store.drawings.append(.point(try n(a[0]), try n(a[1])))
            c.store.pendingShowGraph = true
            return .str("Done")
        }
        reg("Text", 3, 3) { a, c in
            guard case .str(let s) = a[2] else { throw CalcError.dataType }
            c.store.drawings.append(.text(try n(a[0]), try n(a[1]), s))
            c.store.pendingShowGraph = true
            return .str("Done")
        }
        reg("Pt-Off", 2, 2) { a, c in
            let x = try n(a[0]), y = try n(a[1])
            c.store.drawings.removeAll { if case .point(let px, let py) = $0 { return px == x && py == y }; return false }
            c.store.pendingShowGraph = true
            return .str("Done")
        }
        reg("Pt-Change", 2, 2) { a, c in
            let x = try n(a[0]), y = try n(a[1])
            let before = c.store.drawings.count
            c.store.drawings.removeAll { if case .point(let px, let py) = $0 { return px == x && py == y }; return false }
            if c.store.drawings.count == before { c.store.drawings.append(.point(x, y)) }
            c.store.pendingShowGraph = true
            return .str("Done")
        }
        func pxl(_ a: [Value]) throws -> (Double, Double) {
            let r = try n(a[0]), col = try n(a[1])
            guard r >= 0, r <= 164, col >= 0, col <= 264 else { throw CalcError.domain }
            return (r.rounded(), col.rounded())
        }
        reg("Pxl-On", 2, 2) { a, c in
            let (r, col) = try pxl(a)
            if !c.store.drawings.contains(.pixel(r, col)) { c.store.drawings.append(.pixel(r, col)) }
            c.store.pendingShowGraph = true
            return .str("Done")
        }
        reg("Pxl-Off", 2, 2) { a, c in
            let (r, col) = try pxl(a)
            c.store.drawings.removeAll { $0 == .pixel(r, col) }
            c.store.pendingShowGraph = true
            return .str("Done")
        }
        reg("Pxl-Change", 2, 2) { a, c in
            let (r, col) = try pxl(a)
            if c.store.drawings.contains(.pixel(r, col)) { c.store.drawings.removeAll { $0 == .pixel(r, col) } }
            else { c.store.drawings.append(.pixel(r, col)) }
            c.store.pendingShowGraph = true
            return .str("Done")
        }
        reg("pxl-Test", 2, 2) { a, c in
            let (r, col) = try pxl(a)
            return .num(c.store.drawings.contains(.pixel(r, col)) ? 1 : 0)
        }

        // DISTR DRAW
        func shade(_ kind: String, _ params: [Double], _ lo: Double, _ hi: Double, _ c: EvalContext) -> Value {
            let area = Stats.distCDF(kind, params, lo, hi)
            let cap = "Area=\(ResultFormatter.number((area * 1e6).rounded() / 1e6)) low=\(ResultFormatter.number(lo)) up=\(ResultFormatter.number(hi))"
            c.store.drawings.append(.dist(kind, params, lo, hi, cap))
            c.store.pendingShowGraph = true
            return .num(area)
        }
        reg("ShadeNorm", 2, 4) { a, c in
            let mu = a.count > 2 ? try n(a[2]) : 0, sd = a.count > 3 ? try n(a[3]) : 1
            return shade("norm", [mu, sd], try n(a[0]), try n(a[1]), c)
        }
        reg("Shade_t", 3, 3) { a, c in shade("t", [try n(a[2])], try n(a[0]), try n(a[1]), c) }
        reg("Shadeχ²", 3, 3) { a, c in shade("chi2", [try n(a[2])], try n(a[0]), try n(a[1]), c) }
        reg("ShadeF", 4, 4) { a, c in shade("F", [try n(a[2]), try n(a[3])], try n(a[0]), try n(a[1]), c) }

        // MATRIX row operations (return the new matrix; complex matrices and multipliers work too)
        func rowIndex<T>(_ v: Value, _ m: [[T]]) throws -> Int {
            let r = Int(try n(v)) - 1
            guard r >= 0, r < m.count else { throw CalcError.invalidDim }
            return r
        }
        func rows(_ v: Value) throws -> [[Cx]] {
            guard let r = v.asComplexRows else { throw CalcError.dataType }
            return r
        }
        func cxArg(_ v: Value) throws -> Cx {
            guard let z = v.asComplex else { throw CalcError.dataType }
            return Cx(re: z.0, im: z.1)
        }
        reg("rowSwap", 3, 3) { a, _ in
            var mm = try rows(a[0])
            let r1 = try rowIndex(a[1], mm), r2 = try rowIndex(a[2], mm)
            mm.swapAt(r1, r2)
            return Value.fromComplexRows(mm)
        }
        reg("row+", 3, 3) { a, _ in
            var mm = try rows(a[0])
            let r1 = try rowIndex(a[1], mm), r2 = try rowIndex(a[2], mm)
            mm[r2] = zip(mm[r1], mm[r2]).map { $0 + $1 }
            return Value.fromComplexRows(mm)
        }
        reg("*row", 3, 3) { a, _ in
            let k = try cxArg(a[0])
            var mm = try rows(a[1])
            let r = try rowIndex(a[2], mm)
            mm[r] = mm[r].map { $0 * k }
            return Value.fromComplexRows(mm)
        }
        reg("*row+", 4, 4) { a, _ in
            let k = try cxArg(a[0])
            var mm = try rows(a[1])
            let r1 = try rowIndex(a[2], mm), r2 = try rowIndex(a[3], mm)
            mm[r2] = zip(mm[r1], mm[r2]).map { $0 * k + $1 }
            return Value.fromComplexRows(mm)
        }

        // Strings / programs
        reg("length", 1, 1) { a, _ in
            guard case .str(let s) = a[0] else { throw CalcError.dataType }
            return .num(Double(s.count))
        }
        reg("sub", 3, 3) { a, _ in
            guard case .str(let s) = a[0] else { throw CalcError.dataType }
            let start = Int(try n(a[1])) - 1, len = Int(try n(a[2]))
            guard start >= 0, len >= 0, start + len <= s.count else { throw CalcError.domain }
            return .str(String(Array(s)[start..<(start + len)]))
        }
        reg("inString", 2, 3) { a, _ in
            guard case .str(let s) = a[0], case .str(let f) = a[1] else { throw CalcError.dataType }
            let start = a.count == 3 ? Int(try n(a[2])) - 1 : 0
            let chars = Array(s), needle = Array(f)
            guard !needle.isEmpty, start >= 0 else { return .num(0) }
            var i = start
            while i + needle.count <= chars.count {
                if Array(chars[i..<(i + needle.count)]) == needle { return .num(Double(i + 1)) }
                i += 1
            }
            return .num(0)
        }
        reg("getKey", 0, 0) { _, c in .num(Double(c.store.lastKey)) }

        // STAT TESTS: ANOVA(L1, L2, …)
        reg("ANOVA", 2, 20) { a, c in
            let groups = try a.map { try l($0) }
            let r = try Stats.anova(groups)
            for (k, v) in r.values { c.store.stats[k] = v }
            c.store.pendingResults = r.lines
            return .str("Done")
        }
        return t
    }
}
