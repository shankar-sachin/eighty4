import Foundation

/// Statistics, distributions, regressions and the TVM solver.
enum Stats {
    // MARK: - Basic

    static func gcd(_ a: Int, _ b: Int) -> Int {
        var x = abs(a), y = abs(b)
        while y != 0 { (x, y) = (y, x % y) }
        return x
    }

    static func nCr(_ n: Double, _ r: Double) throws -> Double {
        guard n >= 0, r >= 0, n.rounded() == n, r.rounded() == r else { throw CalcError.domain }
        if r > n { return 0 }
        return (exp(lgamma(n + 1) - lgamma(r + 1) - lgamma(n - r + 1))).rounded()
    }

    static func nPr(_ n: Double, _ r: Double) throws -> Double {
        guard n >= 0, r >= 0, n.rounded() == n, r.rounded() == r else { throw CalcError.domain }
        if r > n { return 0 }
        return (exp(lgamma(n + 1) - lgamma(n - r + 1))).rounded()
    }

    static func median(_ x: [Double]) throws -> Double {
        guard !x.isEmpty else { throw CalcError.argument }
        let s = x.sorted()
        let n = s.count
        return n % 2 == 1 ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2
    }

    static func stdDev(_ x: [Double], sample: Bool) throws -> Double {
        guard x.count >= (sample ? 2 : 1) else { throw CalcError.argument }
        let mean = x.reduce(0, +) / Double(x.count)
        let ss = x.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        return sqrt(ss / Double(x.count - (sample ? 1 : 0)))
    }

    static func gaussian() -> Double {
        let u1 = max(Double.random(in: 0..<1), 1e-12), u2 = Double.random(in: 0..<1)
        return sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }

    // MARK: - Distributions

    static func normalPDF(_ x: Double, _ mu: Double, _ sd: Double) -> Double {
        exp(-0.5 * pow((x - mu) / sd, 2)) / (sd * sqrt(2 * .pi))
    }

    static func normalCDF(_ lo: Double, _ hi: Double, _ mu: Double, _ sd: Double) -> Double {
        func phi(_ x: Double) -> Double { 0.5 * (1 + erf((x - mu) / (sd * sqrt(2)))) }
        return phi(hi) - phi(lo)
    }

    /// Acklam's inverse normal approximation with one Newton refinement.
    static func invNorm(_ p: Double) -> Double {
        let a = [-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02, 1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00]
        let b = [-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02, 6.680131188771972e+01, -1.328068155288572e+01]
        let c = [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00, -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00]
        let d = [7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00, 3.754408661907416e+00]
        let pl = 0.02425, ph = 1 - pl
        func horner(_ coef: [Double], _ v: Double) -> Double {
            var acc = 0.0
            for k in coef { acc = acc * v + k }
            return acc
        }
        var x: Double
        if p < pl {
            let q = sqrt(-2 * log(p))
            x = horner(c, q) / horner(d + [1], q)
        } else if p <= ph {
            let q = p - 0.5, r = q * q
            x = horner(a, r) * q / horner(b + [1], r)
        } else {
            let q = sqrt(-2 * log(1 - p))
            x = -horner(c, q) / horner(d + [1], q)
        }
        let e = 0.5 * erfc(-x / sqrt(2)) - p
        let u = e * sqrt(2 * .pi) * exp(x * x / 2)
        x -= u / (1 + x * u / 2)
        return x
    }

    static func tPDF(_ t: Double, _ df: Double) -> Double {
        guard df > 0 else { return 0 }
        let c = exp(lgamma((df + 1) / 2) - lgamma(df / 2)) / sqrt(df * .pi)
        return c * pow(1 + t * t / df, -(df + 1) / 2)
    }

    static func chi2PDF(_ x: Double, _ df: Double) -> Double {
        guard x > 0, df > 0 else { return 0 }
        let k: Double = df / 2
        let ln2: Double = log(2.0)
        let t1: Double = (k - 1) * log(x)
        let t2: Double = x / 2 + k * ln2 + lgamma(k)
        return exp(t1 - t2)
    }

    static func fPDF(_ x: Double, _ d1: Double, _ d2: Double) -> Double {
        guard x > 0, d1 > 0, d2 > 0 else { return 0 }
        let lnB: Double = lgamma(d1 / 2) + lgamma(d2 / 2) - lgamma((d1 + d2) / 2)
        let a: Double = d1 * log(d1 * x)
        let b: Double = d2 * log(d2)
        let c: Double = (d1 + d2) * log(d1 * x + d2)
        let half: Double = 0.5 * (a + b - c)
        return exp(half - log(x) - lnB)
    }

    static func binomPDF(_ n: Double, _ p: Double, _ x: Double) -> Double {
        guard x >= 0, x <= n, x.rounded() == x else { return 0 }
        if p <= 0 { return x == 0 ? 1 : 0 }
        if p >= 1 { return x == n ? 1 : 0 }
        return exp(lgamma(n + 1) - lgamma(x + 1) - lgamma(n - x + 1) + x * log(p) + (n - x) * log(1 - p))
    }

    static func poissonPDF(_ mu: Double, _ x: Double) -> Double {
        guard x >= 0, x.rounded() == x, mu > 0 else { return 0 }
        return exp(-mu + x * log(mu) - lgamma(x + 1))
    }

    /// Simpson integration with infinite bounds clamped to ±clamp.
    static func integrate(_ f: (Double) -> Double, _ lo: Double, _ hi: Double, clamp: Double) -> Double {
        let a = max(-clamp, min(clamp, lo)), b = max(-clamp, min(clamp, hi))
        if b <= a { return 0 }
        let n = 2000
        let h = (b - a) / Double(n)
        var sum = f(a) + f(b)
        for i in 1..<n { sum += (i % 2 == 0 ? 2 : 4) * f(a + Double(i) * h) }
        return sum * h / 3
    }

    static func bisect(_ f: (Double) -> Double, _ lo: Double, _ hi: Double) -> Double {
        var a = lo, b = hi
        var fa = f(a)
        for _ in 0..<100 {
            let m = (a + b) / 2
            let fm = f(m)
            if (fa < 0) == (fm < 0) { a = m; fa = fm } else { b = m }
        }
        return (a + b) / 2
    }

    // MARK: - Stat calculations (results as label/value pairs)

    static func oneVar(_ x: [Double]) throws -> [(String, Double)] {
        guard !x.isEmpty else { throw CalcError.invalidDim }
        let n = Double(x.count)
        let sx = x.reduce(0, +), sxx = x.reduce(0) { $0 + $1 * $1 }
        let mean = sx / n
        let s = x.sorted()
        let sigma = sqrt(sxx / n - mean * mean)
        let sample = x.count > 1 ? try stdDev(x, sample: true) : 0
        let lower = Array(s[0..<(s.count / 2)])
        let upper = Array(s[((s.count + 1) / 2)...])
        return [("x̄", mean), ("Σx", sx), ("Σx²", sxx), ("Sx", sample), ("σx", sigma), ("n", n),
                ("minX", s.first!), ("Q1", lower.isEmpty ? s.first! : try median(lower)), ("Med", try median(s)),
                ("Q3", upper.isEmpty ? s.last! : try median(upper)), ("maxX", s.last!)]
    }

    static func twoVar(_ x: [Double], _ y: [Double]) throws -> [(String, Double)] {
        guard x.count == y.count, !x.isEmpty else { throw CalcError.dimMismatch }
        let n = Double(x.count)
        let sx = x.reduce(0, +), sy = y.reduce(0, +)
        let sxx = x.reduce(0) { $0 + $1 * $1 }, syy = y.reduce(0) { $0 + $1 * $1 }
        let sxy = zip(x, y).reduce(0) { $0 + $1.0 * $1.1 }
        let mx = sx / n, my = sy / n
        return [("x̄", mx), ("Σx", sx), ("Σx²", sxx), ("Sx", x.count > 1 ? try stdDev(x, sample: true) : 0), ("σx", sqrt(sxx / n - mx * mx)), ("n", n),
                ("ȳ", my), ("Σy", sy), ("Σy²", syy), ("Sy", y.count > 1 ? try stdDev(y, sample: true) : 0), ("σy", sqrt(syy / n - my * my)), ("Σxy", sxy),
                ("minX", x.min()!), ("maxX", x.max()!), ("minY", y.min()!), ("maxY", y.max()!)]
    }

    /// Least-squares line y = a·x + b, with r.
    static func linReg(_ x: [Double], _ y: [Double]) throws -> (a: Double, b: Double, r: Double) {
        guard x.count == y.count, x.count >= 2 else { throw CalcError.dimMismatch }
        let n = Double(x.count)
        let sx = x.reduce(0, +), sy = y.reduce(0, +)
        let sxx = x.reduce(0) { $0 + $1 * $1 }, syy = y.reduce(0) { $0 + $1 * $1 }
        let sxy = zip(x, y).reduce(0) { $0 + $1.0 * $1.1 }
        let den = n * sxx - sx * sx
        guard den != 0 else { throw CalcError.domain }
        let a = (n * sxy - sx * sy) / den
        let b = (sy - a * sx) / n
        let rden = sqrt(den * (n * syy - sy * sy))
        let r = rden == 0 ? 0 : (n * sxy - sx * sy) / rden
        return (a, b, r)
    }

    /// Polynomial least squares of the given degree; returns coefficients highest power first.
    static func polyReg(_ x: [Double], _ y: [Double], degree: Int) throws -> [Double] {
        guard x.count == y.count, x.count > degree else { throw CalcError.dimMismatch }
        let cols = degree + 1
        var ata = [[Double]](repeating: [Double](repeating: 0, count: cols), count: cols)
        var aty = [Double](repeating: 0, count: cols)
        for (xi, yi) in zip(x, y) {
            let powers = (0..<cols).map { pow(xi, Double(degree - $0)) }
            for r in 0..<cols {
                aty[r] += powers[r] * yi
                for c in 0..<cols { ata[r][c] += powers[r] * powers[c] }
            }
        }
        let inv = try Matrix.inverse(ata)
        return inv.map { row in zip(row, aty).reduce(0) { $0 + $1.0 * $1.1 } }
    }

    // MARK: - CDF helpers used by tests and DISTR DRAW

    static func tCDF(_ lo: Double, _ hi: Double, _ df: Double) -> Double {
        integrate({ tPDF($0, df) }, lo, hi, clamp: 200)
    }

    static func chi2CDF(_ lo: Double, _ hi: Double, _ df: Double) -> Double {
        integrate({ chi2PDF($0, df) }, max(0, lo), hi, clamp: 5000)
    }

    static func fCDF(_ lo: Double, _ hi: Double, _ d1: Double, _ d2: Double) -> Double {
        integrate({ fPDF($0, d1, d2) }, max(0, lo), hi, clamp: 5000)
    }

    /// Density and area for the four DRAW-able distributions. kind: norm / t / chi2 / F.
    static func distPDF(_ kind: String, _ p: [Double], _ x: Double) -> Double {
        switch kind {
        case "t": return tPDF(x, p.first ?? 1)
        case "chi2": return chi2PDF(x, p.first ?? 1)
        case "F": return fPDF(x, p.first ?? 1, p.count > 1 ? p[1] : 1)
        default: return normalPDF(x, p.first ?? 0, p.count > 1 ? p[1] : 1)
        }
    }

    static func distCDF(_ kind: String, _ p: [Double], _ lo: Double, _ hi: Double) -> Double {
        switch kind {
        case "t": return tCDF(lo, hi, p.first ?? 1)
        case "chi2": return chi2CDF(lo, hi, p.first ?? 1)
        case "F": return fCDF(lo, hi, p.first ?? 1, p.count > 1 ? p[1] : 1)
        default: return normalCDF(lo, hi, p.first ?? 0, p.count > 1 ? p[1] : 1)
        }
    }

    /// Inverse t (two-sided critical value helper): t such that P(T ≤ t) = p.
    static func invT(_ p: Double, _ df: Double) -> Double {
        bisect({ tCDF(-200, $0, df) - p }, -200, 200)
    }

    // MARK: - Nonlinear regressions (Levenberg–Marquardt with numeric Jacobian)

    static func fitNonlinear(_ x: [Double], _ y: [Double], initial: [Double], model: ([Double], Double) -> Double) throws -> [Double] {
        var p = initial
        var lambda = 1e-3
        func sse(_ p: [Double]) -> Double { zip(x, y).reduce(0) { $0 + pow($1.1 - model(p, $1.0), 2) } }
        var current = sse(p)
        for _ in 0..<200 {
            let k = p.count
            var jtj = [[Double]](repeating: [Double](repeating: 0, count: k), count: k)
            var jtr = [Double](repeating: 0, count: k)
            for (xi, yi) in zip(x, y) {
                let r = yi - model(p, xi)
                var grad = [Double](repeating: 0, count: k)
                for j in 0..<k {
                    var pp = p
                    let h = max(1e-6, abs(p[j]) * 1e-6)
                    pp[j] += h
                    grad[j] = (model(pp, xi) - model(p, xi)) / h
                }
                for a in 0..<k {
                    jtr[a] += grad[a] * r
                    for b in 0..<k { jtj[a][b] += grad[a] * grad[b] }
                }
            }
            var damped = jtj
            for i in 0..<k { damped[i][i] *= (1 + lambda) }
            guard let inv = try? Matrix.inverse(damped) else { lambda *= 10; continue }
            let step = inv.map { row in zip(row, jtr).reduce(0) { $0 + $1.0 * $1.1 } }
            let candidate = zip(p, step).map { $0 + $1 }
            let next = sse(candidate)
            if next < current {
                let improvement = current - next
                p = candidate; current = next; lambda = max(1e-9, lambda / 3)
                if improvement < 1e-12 * max(1, current) { break }
            } else {
                lambda *= 5
                if lambda > 1e8 { break }
            }
        }
        guard p.allSatisfy({ $0.isFinite }) else { throw CalcError.domain }
        return p
    }

    /// Logistic y = c / (1 + a·e^(−b·x)). Returns (a, b, c).
    static func logisticReg(_ x: [Double], _ y: [Double]) throws -> (a: Double, b: Double, c: Double) {
        guard x.count == y.count, x.count >= 3, y.allSatisfy({ $0 > 0 }) else { throw CalcError.dimMismatch }
        let c0 = (y.max() ?? 1) * 1.05
        // linearize: ln(c/y − 1) = ln a − b x
        let z = y.map { log(max(1e-9, c0 / $0 - 1)) }
        let lr = try linReg(x, z)
        let p = try fitNonlinear(x, y, initial: [exp(lr.b), -lr.a, c0]) { p, x in p[2] / (1 + p[0] * exp(-p[1] * x)) }
        return (p[0], p[1], p[2])
    }

    /// Sinusoidal y = a·sin(b·x + c) + d. Returns (a, b, c, d).
    static func sinReg(_ x: [Double], _ y: [Double]) throws -> (a: Double, b: Double, c: Double, d: Double) {
        guard x.count == y.count, x.count >= 4 else { throw CalcError.dimMismatch }
        let d0 = y.reduce(0, +) / Double(y.count)
        let a0 = ((y.max() ?? 1) - (y.min() ?? 0)) / 2
        // Period estimate from zero crossings of the centred data.
        let pairs = zip(x, y).sorted { $0.0 < $1.0 }
        var crossings: [Double] = []
        for i in 1..<pairs.count where (pairs[i - 1].1 - d0 < 0) != (pairs[i].1 - d0 < 0) {
            crossings.append((pairs[i - 1].0 + pairs[i].0) / 2)
        }
        let span = (pairs.last!.0 - pairs.first!.0)
        var period = span > 0 ? span : 1
        if crossings.count >= 2 { period = 2 * (crossings.last! - crossings.first!) / Double(crossings.count - 1) }
        let b0 = 2 * .pi / max(1e-9, period)
        var best: [Double]? = nil
        var bestSSE = Double.infinity
        for phase in stride(from: 0.0, to: 2 * .pi, by: .pi / 4) {
            guard let p = try? fitNonlinear(x, y, initial: [a0, b0, phase, d0], model: { p, x in p[0] * sin(p[1] * x + p[2]) + p[3] }) else { continue }
            let sse = zip(x, y).reduce(0) { $0 + pow($1.1 - (p[0] * sin(p[1] * $1.0 + p[2]) + p[3]), 2) }
            if sse < bestSSE { bestSSE = sse; best = p }
        }
        guard var p = best else { throw CalcError.domain }
        if p[0] < 0 { p[0] = -p[0]; p[2] += .pi }
        p[2] = p[2].truncatingRemainder(dividingBy: 2 * .pi)
        return (p[0], p[1], p[2], p[3])
    }

    // MARK: - ANOVA

    struct ANOVAResult {
        var lines: [String]
        var values: [(String, Double)]
    }

    static func anova(_ groups: [[Double]]) throws -> ANOVAResult {
        guard groups.count >= 2, groups.allSatisfy({ $0.count >= 1 }) else { throw CalcError.dimMismatch }
        let all = groups.flatMap { $0 }
        let n = Double(all.count), k = Double(groups.count)
        let grand = all.reduce(0, +) / n
        let ssb = groups.reduce(0.0) { acc, g in
            let m = g.reduce(0, +) / Double(g.count)
            return acc + Double(g.count) * (m - grand) * (m - grand)
        }
        let ssw = groups.reduce(0.0) { acc, g in
            let m = g.reduce(0, +) / Double(g.count)
            return acc + g.reduce(0) { $0 + ($1 - m) * ($1 - m) }
        }
        let dfb = k - 1, dfw = n - k
        guard dfw > 0 else { throw CalcError.dimMismatch }
        let msb = ssb / dfb, msw = ssw / dfw
        let f = msw == 0 ? Double.infinity : msb / msw
        let p = f.isFinite ? max(0, 1 - fCDF(0, f, dfb, dfw)) : 0
        func fmt(_ v: Double) -> String { ResultFormatter.number(v) }
        let lines = ["One-way ANOVA", " F=\(fmt(f))", " p=\(fmt(p))", "Factor", "  df=\(fmt(dfb))", "  SS=\(fmt(ssb))", "  MS=\(fmt(msb))",
                     "Error", "  df=\(fmt(dfw))", "  SS=\(fmt(ssw))", "  MS=\(fmt(msw))", "  Sxp=\(fmt(sqrt(msw)))"]
        return ANOVAResult(lines: lines, values: [("F", f), ("p", p), ("df", dfb), ("Sxp", sqrt(msw))])
    }

    // MARK: - TVM

    /// Solves the TVM equation for `key` given the other values in `v`.
    static func tvmSolve(_ key: String, _ v: [String: Double], begin: Bool) throws -> Double {
        let N = v["N"] ?? 0, I = v["I%"] ?? 0, PV = v["PV"] ?? 0, PMT = v["PMT"] ?? 0, FV = v["FV"] ?? 0
        let PY = max(1, v["P/Y"] ?? 1), CY = max(1, v["C/Y"] ?? 1)
        func rate(_ i: Double) -> Double { pow(1 + i / 100 / CY, CY / PY) - 1 }
        func f(_ n: Double, _ i: Double, _ pv: Double, _ pmt: Double, _ fv: Double) -> Double {
            let r = rate(i)
            if abs(r) < 1e-12 { return pv + pmt * n + fv }
            let g = pow(1 + r, -n)
            return pv + pmt * (1 + r * (begin ? 1 : 0)) * (1 - g) / r + fv * g
        }
        switch key {
        case "PV": return -(f(N, I, 0, PMT, FV))
        case "FV":
            let r = rate(I)
            if abs(r) < 1e-12 { return -(PV + PMT * N) }
            let g = pow(1 + r, -N)
            return -((PV + PMT * (1 + r * (begin ? 1 : 0)) * (1 - g) / r) / g)
        case "PMT":
            let r = rate(I)
            if abs(r) < 1e-12 { guard N != 0 else { throw CalcError.domain }; return -(PV + FV) / N }
            let g = pow(1 + r, -N)
            let ann = (1 + r * (begin ? 1 : 0)) * (1 - g) / r
            guard ann != 0 else { throw CalcError.domain }
            return -(PV + FV * g) / ann
        case "N":
            let lo = 0.0, hi = 100_000.0
            let flo = f(lo, I, PV, PMT, FV), fhi = f(hi, I, PV, PMT, FV)
            guard (flo < 0) != (fhi < 0) else { throw CalcError.noSignChange }
            return bisect({ f($0, I, PV, PMT, FV) }, lo, hi)
        case "I%":
            var prev = -99.0, fprev = f(N, prev, PV, PMT, FV)
            var i = prev + 0.5
            while i <= 1000 {
                let fi = f(N, i, PV, PMT, FV)
                if (fprev < 0) != (fi < 0) { return bisect({ f(N, $0, PV, PMT, FV) }, prev, i) }
                prev = i; fprev = fi; i += 0.5
            }
            throw CalcError.noSignChange
        default:
            throw CalcError.argument
        }
    }
}
