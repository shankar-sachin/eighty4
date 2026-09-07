import Foundation

enum BinaryOp: Equatable {
    case add, sub, mul, div, pow, nthRoot, nCr, nPr
    case eq, ne, gt, ge, lt, le
    case and, or, xor
    case mixed   // Un/d mixed-number separator "_"
}

/// A TI-84 value: real number, fraction display form, complex number, list, matrix, or string.
enum Value: Equatable {
    case num(Double)
    case fraction(Int, Int)
    case complex(Double, Double)   // re + im·i, never with im == 0 (see `cx`)
    case list([Double])
    case clist([Cx])               // complex list; at least one element has im ≠ 0 (see `fromComplexElements`)
    case matrix([[Double]])
    case cmatrix([[Cx]])           // complex matrix; at least one element has im ≠ 0 (see `fromComplexRows`)
    case str(String)

    /// Set per evaluation from MODE: a+bi / re^θi let √(⁻1) and (⁻8)^(1/3) produce complex results;
    /// REAL mode raises ERR:NONREAL ANS instead. Explicit `i` always works.
    nonisolated(unsafe) static var complexResults = false

    var asDouble: Double? {
        switch self {
        case .num(let d): return d
        case .fraction(let n, let d): return Double(n) / Double(d)
        default: return nil
        }
    }

    /// Real and complex values as (re, im); nil for lists, matrices, strings.
    var asComplex: (Double, Double)? {
        if case .complex(let re, let im) = self { return (re, im) }
        if let d = asDouble { return (d, 0) }
        return nil
    }

    var isComplex: Bool { if case .complex = self { return true }; return false }
    var isComplexList: Bool { if case .clist = self { return true }; return false }
    var isRealList: Bool { if case .list = self { return true }; return false }
    var isComplexMatrix: Bool { if case .cmatrix = self { return true }; return false }
    var isAnyMatrix: Bool {
        switch self { case .matrix, .cmatrix: return true; default: return false }
    }

    /// Rows of a real or complex matrix as complex elements; nil for anything else.
    var asComplexRows: [[Cx]]? {
        switch self {
        case .matrix(let m): return m.map { $0.map { Cx(re: $0, im: 0) } }
        case .cmatrix(let m): return m
        default: return nil
        }
    }

    /// Builds a matrix, collapsing to a real matrix when every imaginary part is exactly zero.
    static func fromComplexRows(_ rows: [[Cx]]) -> Value {
        rows.allSatisfy { $0.allSatisfy { $0.im == 0 } } ? .matrix(rows.map { $0.map(\.re) }) : .cmatrix(rows)
    }

    /// Elements of a real or complex list as (re, im) pairs.
    var asComplexElements: [(Double, Double)]? {
        switch self {
        case .list(let l): return l.map { ($0, 0) }
        case .clist(let l): return l.map { ($0.re, $0.im) }
        default: return nil
        }
    }

    /// Builds a complex value, collapsing to a real when the imaginary part is exactly zero.
    static func cx(_ re: Double, _ im: Double) -> Value { im == 0 ? .num(re) : .complex(re, im) }

    /// Builds a list, collapsing to a real list when every imaginary part is exactly zero.
    static func fromComplexElements(_ xs: [(Double, Double)]) -> Value {
        xs.allSatisfy { $0.1 == 0 } ? .list(xs.map { $0.0 }) : .clist(xs.map { Cx(re: $0.0, im: $0.1) })
    }

    func number() throws -> Double {
        guard let d = asDouble else { throw CalcError.dataType }
        return d
    }

    func listValue() throws -> [Double] {
        if case .list(let l) = self { return l }
        throw CalcError.dataType
    }

    func matrixValue() throws -> [[Double]] {
        if case .matrix(let m) = self { return m }
        throw CalcError.dataType
    }

    func negated() throws -> Value {
        switch self {
        case .num(let d): return .num(-d)
        case .fraction(let n, let d): return .fraction(-n, d)
        case .complex(let re, let im): return .complex(-re, -im)
        case .list(let l): return .list(l.map { -$0 })
        case .clist(let l): return .clist(l.map { Cx(re: -$0.re, im: -$0.im) })
        case .matrix(let m): return .matrix(m.map { $0.map { -$0 } })
        case .cmatrix(let m): return .cmatrix(m.map { $0.map { Cx(re: -$0.re, im: -$0.im) } })
        case .str: throw CalcError.dataType
        }
    }

    /// Applies a scalar function element-wise to numbers and lists.
    func mapNumbers(_ f: (Double) throws -> Double) throws -> Value {
        switch self {
        case .list(let l): return .list(try l.map(f))
        default: return .num(try f(try number()))
        }
    }

    static func apply(_ op: BinaryOp, _ a: Value, _ b: Value) throws -> Value {
        if (a.isAnyMatrix || b.isAnyMatrix) && (a.isComplexMatrix || b.isComplexMatrix || a.isComplex || b.isComplex) {
            return try complexMatrixApply(op, a, b)
        }
        if a.isComplexList || b.isComplexList || (a.isComplex && b.isRealList) || (a.isRealList && b.isComplex) {
            return try complexListApply(op, a, b)
        }
        if a.isComplex || b.isComplex {
            guard let x = a.asComplex, let y = b.asComplex else { throw CalcError.dataType }
            return try ComplexMath.apply(op, x, y)
        }
        switch (a, b) {
        case (.str(let x), .str(let y)):
            if op == .add { return .str(x + y) }
            if op == .eq { return .num(x == y ? 1 : 0) }
            if op == .ne { return .num(x != y ? 1 : 0) }
            throw CalcError.dataType
        case (.matrix(let m), .matrix(let n)):
            return .matrix(try Matrix.binary(op, m, n))
        case (.matrix(let m), _):
            let s = try b.number()
            if op == .pow { return .matrix(try Matrix.power(m, s, isInteger: s.rounded() == s)) }
            return .matrix(try Matrix.scalar(op, m, s, matrixFirst: true))
        case (_, .matrix(let n)):
            return .matrix(try Matrix.scalar(op, n, try a.number(), matrixFirst: false))
        case (.list(let x), .list(let y)):
            guard x.count == y.count else { throw CalcError.dimMismatch }
            return .list(try zip(x, y).map { try scalar(op, $0, $1) })
        case (.list(let x), _):
            let s = try b.number()
            return .list(try x.map { try scalar(op, $0, s) })
        case (_, .list(let y)):
            let s = try a.number()
            return .list(try y.map { try scalar(op, s, $0) })
        case (.str, _), (_, .str):
            throw CalcError.dataType
        default:
            let x = try a.number(), y = try b.number()
            // A negative base with a fractional exponent (or an even root of a negative) is only real-valued
            // as a complex number: allowed in a+bi / re^θi mode, ERR:NONREAL ANS in REAL mode.
            if op == .pow, x < 0, y.rounded() != y {
                guard complexResults else { throw CalcError.nonrealAns }
                return try ComplexMath.apply(.pow, (x, 0), (y, 0))
            }
            if op == .nthRoot, y < 0, x.rounded() == x, Int(x) % 2 == 0 {
                guard complexResults, x != 0 else { throw CalcError.nonrealAns }
                return try ComplexMath.apply(.pow, (y, 0), (1 / x, 0))
            }
            return .num(try scalar(op, x, y))
        }
    }

    /// Matrix arithmetic when a complex matrix or a complex scalar is involved; results collapse to real matrices.
    private static func complexMatrixApply(_ op: BinaryOp, _ a: Value, _ b: Value) throws -> Value {
        switch (a.asComplexRows, b.asComplexRows) {
        case (let m?, let n?):
            return fromComplexRows(try Matrix.binary(op, m, n))
        case (let m?, nil):
            guard let s = b.asComplex else { throw CalcError.dataType }
            if op == .pow { return fromComplexRows(try Matrix.power(m, s.0, isInteger: s.1 == 0 && s.0.rounded() == s.0)) }
            return fromComplexRows(try Matrix.scalar(op, m, Cx(re: s.0, im: s.1), matrixFirst: true))
        case (nil, let n?):
            guard let s = a.asComplex else { throw CalcError.dataType }
            return fromComplexRows(try Matrix.scalar(op, n, Cx(re: s.0, im: s.1), matrixFirst: false))
        default:
            throw CalcError.dataType
        }
    }

    /// Element-wise complex arithmetic between lists and scalars (list∘list, list∘scalar, scalar∘list).
    private static func complexListApply(_ op: BinaryOp, _ a: Value, _ b: Value) throws -> Value {
        func pair(_ v: Value) -> (Double, Double) { v.asComplex ?? (0, 0) }
        let xs = a.asComplexElements, ys = b.asComplexElements
        var out: [(Double, Double)] = []
        if let xs, let ys {
            guard xs.count == ys.count else { throw CalcError.dimMismatch }
            for (x, y) in zip(xs, ys) { out.append(pair(try ComplexMath.apply(op, x, y))) }
        } else if let xs, let s = b.asComplex {
            for x in xs { out.append(pair(try ComplexMath.apply(op, x, s))) }
        } else if let ys, let s = a.asComplex {
            for y in ys { out.append(pair(try ComplexMath.apply(op, s, y))) }
        } else {
            throw CalcError.dataType
        }
        return fromComplexElements(out)
    }

    static func scalar(_ op: BinaryOp, _ x: Double, _ y: Double) throws -> Double {
        switch op {
        case .add: return x + y
        case .sub: return x - y
        case .mul: return x * y
        case .div:
            if y == 0 { throw CalcError.divideByZero }
            return x / y
        case .pow:
            let r = pow(x, y)
            if r.isNaN { throw CalcError.domain }
            return r
        case .nthRoot:
            // TI syntax: n ˣ√ x
            if x == 0 { throw CalcError.domain }
            let odd = x.rounded() == x && Int(x) % 2 != 0
            let r = (y < 0 && odd) ? -pow(-y, 1 / x) : pow(y, 1 / x)
            if r.isNaN { throw CalcError.domain }
            return r
        case .nCr: return try Stats.nCr(x, y)
        case .nPr: return try Stats.nPr(x, y)
        case .eq: return x == y ? 1 : 0
        case .ne: return x != y ? 1 : 0
        case .gt: return x > y ? 1 : 0
        case .ge: return x >= y ? 1 : 0
        case .lt: return x < y ? 1 : 0
        case .le: return x <= y ? 1 : 0
        case .and: return (x != 0 && y != 0) ? 1 : 0
        case .or: return (x != 0 || y != 0) ? 1 : 0
        case .xor: return ((x != 0) != (y != 0)) ? 1 : 0
        case .mixed: throw CalcError.syntax
        }
    }

    /// Best rational approximation with denominator ≤ 9999, or nil.
    static func fraction(from x: Double) -> Value? {
        if x.rounded() == x, abs(x) < 1e12 { return .fraction(Int(x), 1) }
        let sign = x < 0 ? -1 : 1
        var v = abs(x)
        var h1 = 1, h0 = 0, k1 = 0, k0 = 1
        for _ in 0..<40 {
            let a = Int(floor(v))
            let h2 = a * h1 + h0
            let k2 = a * k1 + k0
            if k2 > 9999 { break }
            h0 = h1; h1 = h2; k0 = k1; k1 = k2
            if abs(abs(x) - Double(h1) / Double(k1)) < 1e-10 { return .fraction(sign * h1, k1) }
            let frac = v - Double(a)
            if frac < 1e-12 { break }
            v = 1 / frac
        }
        return nil
    }
}

/// Complex arithmetic on (re, im) pairs. Results go through `Value.cx` so exact-zero imaginary parts collapse to reals.
enum ComplexMath {
    typealias C = (Double, Double)

    static func apply(_ op: BinaryOp, _ a: C, _ b: C) throws -> Value {
        switch op {
        case .add: return Value.cx(a.0 + b.0, a.1 + b.1)
        case .sub: return Value.cx(a.0 - b.0, a.1 - b.1)
        case .mul: let r = mul(a, b); return Value.cx(r.0, r.1)
        case .div: let r = try div(a, b); return Value.cx(r.0, r.1)
        case .pow: let r = try pow(a, b); return Value.cx(r.0, r.1)
        case .nthRoot: let r = try pow(b, try div((1, 0), a)); return Value.cx(r.0, r.1)
        case .eq: return .num(a == b ? 1 : 0)
        case .ne: return .num(a == b ? 0 : 1)
        default: throw CalcError.dataType
        }
    }

    static func mul(_ a: C, _ b: C) -> C { (a.0 * b.0 - a.1 * b.1, a.0 * b.1 + a.1 * b.0) }

    static func div(_ a: C, _ b: C) throws -> C {
        let d = b.0 * b.0 + b.1 * b.1
        if d == 0 { throw CalcError.divideByZero }
        return ((a.0 * b.0 + a.1 * b.1) / d, (a.1 * b.0 - a.0 * b.1) / d)
    }

    static func abs(_ z: C) -> Double { hypot(z.0, z.1) }
    static func angle(_ z: C) -> Double { atan2(z.1, z.0) }
    static func exp(_ z: C) -> C { let m = Foundation.exp(z.0); return (m * cos(z.1), m * sin(z.1)) }

    static func ln(_ z: C) throws -> C {
        if z.0 == 0 && z.1 == 0 { throw CalcError.domain }
        return (log(abs(z)), angle(z))
    }

    static func sqrt(_ z: C) -> C {
        let r = abs(z)
        let re = ((r + z.0) / 2).squareRoot()
        let im = ((r - z.0) / 2).squareRoot()
        return (re, z.1 < 0 ? -im : im)
    }

    static func pow(_ z: C, _ w: C) throws -> C {
        if z.0 == 0 && z.1 == 0 {
            if w.0 == 0 && w.1 == 0 { return (1, 0) }
            if w.1 == 0 && w.0 > 0 { return (0, 0) }
            throw CalcError.domain
        }
        // Small integer powers by repeated multiplication keep results exact ((1+i)² = 2i).
        if w.1 == 0, w.0.rounded() == w.0, Swift.abs(w.0) <= 64 {
            var result: C = (1, 0)
            for _ in 0..<Int(Swift.abs(w.0)) { result = mul(result, z) }
            return w.0 < 0 ? try div((1, 0), result) : result
        }
        return exp(mul(w, try ln(z)))
    }
}

/// Scalar type a matrix can hold: reals and complex numbers.
protocol MatrixScalar: Equatable {
    static var zero: Self { get }
    static var one: Self { get }
    static func + (a: Self, b: Self) -> Self
    static func - (a: Self, b: Self) -> Self
    static func * (a: Self, b: Self) -> Self
    static func / (a: Self, b: Self) -> Self
    var magnitude: Double { get }
}

extension Double: MatrixScalar {
    static var one: Double { 1 }
}

enum Matrix {
    static func dims<T>(_ m: [[T]]) -> (Int, Int) { (m.count, m.first?.count ?? 0) }

    static func binary<T: MatrixScalar>(_ op: BinaryOp, _ m: [[T]], _ n: [[T]]) throws -> [[T]] {
        switch op {
        case .add, .sub:
            guard dims(m) == dims(n) else { throw CalcError.dimMismatch }
            var out = m
            for r in 0..<m.count {
                for c in 0..<m[r].count {
                    let x: T = m[r][c], y: T = n[r][c]
                    out[r][c] = op == .add ? x + y : x - y
                }
            }
            return out
        case .mul:
            let (mr, mc) = dims(m), (nr, nc) = dims(n)
            guard mc == nr else { throw CalcError.dimMismatch }
            var out: [[T]] = Array(repeating: Array(repeating: T.zero, count: nc), count: mr)
            for r in 0..<mr {
                for c in 0..<nc {
                    var acc = T.zero
                    for k in 0..<mc { let p: T = m[r][k] * n[k][c]; acc = acc + p }
                    out[r][c] = acc
                }
            }
            return out
        default:
            throw CalcError.dataType
        }
    }

    static func scalar<T: MatrixScalar>(_ op: BinaryOp, _ m: [[T]], _ s: T, matrixFirst: Bool) throws -> [[T]] {
        switch op {
        case .mul: return m.map { $0.map { $0 * s } }
        case .div:
            guard matrixFirst else { throw CalcError.dataType }
            if s.magnitude == 0 { throw CalcError.divideByZero }
            return m.map { $0.map { $0 / s } }
        default:
            throw CalcError.dataType
        }
    }

    /// [A]^n for integer n (n = ⁻1 is the inverse).
    static func power<T: MatrixScalar>(_ m: [[T]], _ s: Double, isInteger: Bool) throws -> [[T]] {
        guard isSquare(m), isInteger else { throw CalcError.dataType }
        let n = Int(s)
        if n == -1 { return try inverse(m) }
        guard n >= 0, n <= 64 else { throw CalcError.domain }
        var result: [[T]] = identity(m.count)
        for _ in 0..<n { result = try binary(.mul, result, m) }
        return result
    }

    static func isSquare<T>(_ m: [[T]]) -> Bool { let (r, c) = dims(m); return r == c && r > 0 }

    static func identity<T: MatrixScalar>(_ n: Int) -> [[T]] {
        (0..<n).map { r in (0..<n).map { $0 == r ? T.one : T.zero } }
    }

    static func transpose<T>(_ m: [[T]]) -> [[T]] {
        let (r, c) = dims(m)
        guard r > 0 else { return m }
        return (0..<c).map { j in (0..<r).map { i in m[i][j] } }
    }

    static func det<T: MatrixScalar>(_ m: [[T]]) throws -> T {
        guard isSquare(m) else { throw CalcError.invalidDim }
        var a = m
        let n = a.count
        var d = T.one
        for i in 0..<n {
            var p = i
            for r in i..<n where a[r][i].magnitude > a[p][i].magnitude { p = r }
            if a[p][i].magnitude < 1e-14 { return T.zero }
            if p != i { a.swapAt(p, i); d = T.zero - d }
            d = d * a[i][i]
            for r in (i + 1)..<n {
                let f = a[r][i] / a[i][i]
                for c in i..<n { a[r][c] = a[r][c] - f * a[i][c] }
            }
        }
        return d
    }

    static func inverse<T: MatrixScalar>(_ m: [[T]]) throws -> [[T]] {
        guard isSquare(m) else { throw CalcError.invalidDim }
        let n = m.count
        var a = m
        var inv: [[T]] = identity(n)
        for i in 0..<n {
            var p = i
            for r in i..<n where a[r][i].magnitude > a[p][i].magnitude { p = r }
            if a[p][i].magnitude < 1e-12 { throw CalcError.singular }
            a.swapAt(p, i); inv.swapAt(p, i)
            let pivot = a[i][i]
            for c in 0..<n { a[i][c] = a[i][c] / pivot; inv[i][c] = inv[i][c] / pivot }
            for r in 0..<n where r != i {
                let f = a[r][i]
                if f.magnitude == 0 { continue }
                for c in 0..<n { a[r][c] = a[r][c] - f * a[i][c]; inv[r][c] = inv[r][c] - f * inv[i][c] }
            }
        }
        return inv
    }

    /// Reduced row echelon form.
    static func rref<T: MatrixScalar>(_ m: [[T]]) -> [[T]] {
        var a = m
        let (rows, cols) = dims(a)
        var lead = 0
        for r in 0..<rows {
            if lead >= cols { break }
            var i = r
            while a[i][lead].magnitude < 1e-12 {
                i += 1
                if i == rows { i = r; lead += 1; if lead == cols { return a } }
            }
            a.swapAt(i, r)
            let lv = a[r][lead]
            a[r] = a[r].map { $0 / lv }
            for k in 0..<rows where k != r {
                let f = a[k][lead]
                for c in 0..<cols { a[k][c] = a[k][c] - f * a[r][c] }
            }
            lead += 1
        }
        return a
    }

    static func ref<T: MatrixScalar>(_ m: [[T]]) -> [[T]] {
        var a = m
        let (rows, cols) = dims(a)
        var r = 0
        for c in 0..<cols where r < rows {
            var p = r
            for i in r..<rows where a[i][c].magnitude > a[p][c].magnitude { p = i }
            if a[p][c].magnitude < 1e-12 { continue }
            a.swapAt(p, r)
            let pv = a[r][c]
            a[r] = a[r].map { $0 / pv }
            for i in (r + 1)..<rows {
                let f = a[i][c]
                for j in 0..<cols { a[i][j] = a[i][j] - f * a[r][j] }
            }
            r += 1
        }
        return a
    }
}
