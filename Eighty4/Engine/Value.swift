import Foundation

enum BinaryOp: Equatable {
    case add, sub, mul, div, pow, nthRoot, nCr, nPr
    case eq, ne, gt, ge, lt, le
    case and, or, xor
    case mixed   // Un/d mixed-number separator "_"
}

/// A TI-84 value: real number, fraction display form, list, matrix, or string.
enum Value: Equatable {
    case num(Double)
    case fraction(Int, Int)
    case list([Double])
    case matrix([[Double]])
    case str(String)

    var asDouble: Double? {
        switch self {
        case .num(let d): return d
        case .fraction(let n, let d): return Double(n) / Double(d)
        default: return nil
        }
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
        case .list(let l): return .list(l.map { -$0 })
        case .matrix(let m): return .matrix(m.map { $0.map { -$0 } })
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
        switch (a, b) {
        case (.str(let x), .str(let y)):
            if op == .add { return .str(x + y) }
            if op == .eq { return .num(x == y ? 1 : 0) }
            if op == .ne { return .num(x != y ? 1 : 0) }
            throw CalcError.dataType
        case (.matrix(let m), .matrix(let n)):
            return .matrix(try Matrix.binary(op, m, n))
        case (.matrix(let m), _):
            return .matrix(try Matrix.scalar(op, m, try b.number(), matrixFirst: true))
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
            return .num(try scalar(op, try a.number(), try b.number()))
        }
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

enum Matrix {
    static func dims(_ m: [[Double]]) -> (Int, Int) { (m.count, m.first?.count ?? 0) }

    static func binary(_ op: BinaryOp, _ m: [[Double]], _ n: [[Double]]) throws -> [[Double]] {
        switch op {
        case .add, .sub:
            guard dims(m) == dims(n) else { throw CalcError.dimMismatch }
            return try (0..<m.count).map { r in try (0..<m[r].count).map { c in try Value.scalar(op, m[r][c], n[r][c]) } }
        case .mul:
            let (mr, mc) = dims(m), (nr, nc) = dims(n)
            guard mc == nr else { throw CalcError.dimMismatch }
            return (0..<mr).map { r in (0..<nc).map { c in (0..<mc).reduce(0) { $0 + m[r][$1] * n[$1][c] } } }
        default:
            throw CalcError.dataType
        }
    }

    static func scalar(_ op: BinaryOp, _ m: [[Double]], _ s: Double, matrixFirst: Bool) throws -> [[Double]] {
        switch op {
        case .mul: return m.map { $0.map { $0 * s } }
        case .div:
            guard matrixFirst else { throw CalcError.dataType }
            if s == 0 { throw CalcError.divideByZero }
            return m.map { $0.map { $0 / s } }
        case .pow:
            guard matrixFirst, isSquare(m), s.rounded() == s else { throw CalcError.dataType }
            let n = Int(s)
            if n == -1 { return try inverse(m) }
            guard n >= 0, n <= 64 else { throw CalcError.domain }
            var result = identity(m.count)
            for _ in 0..<n { result = try binary(.mul, result, m) }
            return result
        default:
            throw CalcError.dataType
        }
    }

    static func isSquare(_ m: [[Double]]) -> Bool { let (r, c) = dims(m); return r == c && r > 0 }

    static func identity(_ n: Int) -> [[Double]] {
        (0..<n).map { r in (0..<n).map { $0 == r ? 1 : 0 } }
    }

    static func transpose(_ m: [[Double]]) -> [[Double]] {
        let (r, c) = dims(m)
        guard r > 0 else { return m }
        return (0..<c).map { j in (0..<r).map { i in m[i][j] } }
    }

    static func det(_ m: [[Double]]) throws -> Double {
        guard isSquare(m) else { throw CalcError.invalidDim }
        var a = m
        let n = a.count
        var d = 1.0
        for i in 0..<n {
            var p = i
            for r in i..<n where abs(a[r][i]) > abs(a[p][i]) { p = r }
            if abs(a[p][i]) < 1e-14 { return 0 }
            if p != i { a.swapAt(p, i); d = -d }
            d *= a[i][i]
            for r in (i + 1)..<n {
                let f = a[r][i] / a[i][i]
                for c in i..<n { a[r][c] -= f * a[i][c] }
            }
        }
        return d
    }

    static func inverse(_ m: [[Double]]) throws -> [[Double]] {
        guard isSquare(m) else { throw CalcError.invalidDim }
        let n = m.count
        var a = m
        var inv = identity(n)
        for i in 0..<n {
            var p = i
            for r in i..<n where abs(a[r][i]) > abs(a[p][i]) { p = r }
            if abs(a[p][i]) < 1e-12 { throw CalcError.singular }
            a.swapAt(p, i); inv.swapAt(p, i)
            let pivot = a[i][i]
            for c in 0..<n { a[i][c] /= pivot; inv[i][c] /= pivot }
            for r in 0..<n where r != i {
                let f = a[r][i]
                if f == 0 { continue }
                for c in 0..<n { a[r][c] -= f * a[i][c]; inv[r][c] -= f * inv[i][c] }
            }
        }
        return inv
    }

    /// Reduced row echelon form.
    static func rref(_ m: [[Double]]) -> [[Double]] {
        var a = m
        let (rows, cols) = dims(a)
        var lead = 0
        for r in 0..<rows {
            if lead >= cols { break }
            var i = r
            while abs(a[i][lead]) < 1e-12 {
                i += 1
                if i == rows { i = r; lead += 1; if lead == cols { return a } }
            }
            a.swapAt(i, r)
            let lv = a[r][lead]
            a[r] = a[r].map { $0 / lv }
            for k in 0..<rows where k != r {
                let f = a[k][lead]
                for c in 0..<cols { a[k][c] -= f * a[r][c] }
            }
            lead += 1
        }
        return a
    }

    static func ref(_ m: [[Double]]) -> [[Double]] {
        var a = m
        let (rows, cols) = dims(a)
        var r = 0
        for c in 0..<cols where r < rows {
            var p = r
            for i in r..<rows where abs(a[i][c]) > abs(a[p][c]) { p = i }
            if abs(a[p][c]) < 1e-12 { continue }
            a.swapAt(p, r)
            let pv = a[r][c]
            a[r] = a[r].map { $0 / pv }
            for i in (r + 1)..<rows {
                let f = a[i][c]
                for j in 0..<cols { a[i][j] -= f * a[r][j] }
            }
            r += 1
        }
        return a
    }
}
