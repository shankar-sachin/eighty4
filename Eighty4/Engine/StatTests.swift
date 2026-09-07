import Foundation

/// STAT TESTS: each test is an editor (rows depend on Inpt) plus a calculation that
/// produces the results screen, the VARS Statistics TEST values, and an optional DRAW.
enum StatTest: Equatable, CaseIterable {
    case zTest, tTest, twoSampZTest, twoSampTTest, onePropZTest, twoPropZTest
    case zInterval, tInterval, twoSampZInt, twoSampTInt, onePropZInt, twoPropZInt
    case chi2Test, chi2GOF, twoSampFTest, linRegTTest, linRegTInt

    var title: String {
        switch self {
        case .zTest: return "Z-Test"
        case .tTest: return "T-Test"
        case .twoSampZTest: return "2-SampZTest"
        case .twoSampTTest: return "2-SampTTest"
        case .onePropZTest: return "1-PropZTest"
        case .twoPropZTest: return "2-PropZTest"
        case .zInterval: return "ZInterval"
        case .tInterval: return "TInterval"
        case .twoSampZInt: return "2-SampZInt"
        case .twoSampTInt: return "2-SampTInt"
        case .onePropZInt: return "1-PropZInt"
        case .twoPropZInt: return "2-PropZInt"
        case .chi2Test: return "χ²-Test"
        case .chi2GOF: return "χ²GOF-Test"
        case .twoSampFTest: return "2-SampFTest"
        case .linRegTTest: return "LinRegTTest"
        case .linRegTInt: return "LinRegTInt"
        }
    }

    var isInterval: Bool {
        switch self {
        case .zInterval, .tInterval, .twoSampZInt, .twoSampTInt, .onePropZInt, .twoPropZInt, .linRegTInt: return true
        default: return false
        }
    }

    // MARK: - Editor rows

    private static let listNames = ["L1", "L2", "L3", "L4", "L5", "L6"]
    private static let matNames = Array("ABCDEFGHIJ").map { "[\($0)]" }

    private static func opt(_ key: String, _ label: String?, _ options: [String]) -> EditorRow {
        .options(SettingRow(key: key, label: label, options: options))
    }
    private static func num(_ key: String, _ label: String) -> EditorRow { .number(key: "t." + key, label: label) }
    private static var inpt: EditorRow { opt("t.Inpt", "Inpt:", ["Data", "Stats"]) }
    private static func list(_ key: String, _ label: String) -> EditorRow { opt("t." + key, label, listNames) }
    private static var calcDraw: EditorRow { opt("calcDraw", nil, ["Calculate", "Draw"]) }
    private static var calcOnly: EditorRow { opt("calcDraw", nil, ["Calculate"]) }
    private static var pooled: EditorRow { opt("t.Pooled", "Pooled:", ["No", "Yes"]) }
    private static var cLevel: EditorRow { num("C-Level", "C-Level") }

    func rows(store: VariableStore) -> [EditorRow] {
        let data = store.options["t.Inpt", default: 0] == 0
        let one = data ? [Self.list("List", "List:"), Self.num("Freq", "Freq")] : []
        let two = data ? [Self.list("List1", "List1:"), Self.list("List2", "List2:"), Self.num("Freq1", "Freq1"), Self.num("Freq2", "Freq2")] : []
        switch self {
        case .zTest:
            return [Self.inpt, Self.num("μ0", "μ0"), Self.num("σ", "σ")] + (data ? one : [Self.num("x̄", "x̄"), Self.num("n", "n")])
                + [Self.opt("t.alt", "μ:", ["≠μ0", "<μ0", ">μ0"]), Self.calcDraw]
        case .tTest:
            return [Self.inpt, Self.num("μ0", "μ0")] + (data ? one : [Self.num("x̄", "x̄"), Self.num("Sx", "Sx"), Self.num("n", "n")])
                + [Self.opt("t.alt", "μ:", ["≠μ0", "<μ0", ">μ0"]), Self.calcDraw]
        case .twoSampZTest:
            return [Self.inpt, Self.num("σ1", "σ1"), Self.num("σ2", "σ2")]
                + (data ? two : [Self.num("x̄1", "x̄1"), Self.num("n1", "n1"), Self.num("x̄2", "x̄2"), Self.num("n2", "n2")])
                + [Self.opt("t.alt", "μ1:", ["≠μ2", "<μ2", ">μ2"]), Self.calcDraw]
        case .twoSampTTest:
            return [Self.inpt] + (data ? two : [Self.num("x̄1", "x̄1"), Self.num("Sx1", "Sx1"), Self.num("n1", "n1"), Self.num("x̄2", "x̄2"), Self.num("Sx2", "Sx2"), Self.num("n2", "n2")])
                + [Self.opt("t.alt", "μ1:", ["≠μ2", "<μ2", ">μ2"]), Self.pooled, Self.calcDraw]
        case .onePropZTest:
            return [Self.num("p0", "p0"), Self.num("x", "x"), Self.num("n", "n"), Self.opt("t.alt", "prop:", ["≠p0", "<p0", ">p0"]), Self.calcDraw]
        case .twoPropZTest:
            return [Self.num("x1", "x1"), Self.num("n1", "n1"), Self.num("x2", "x2"), Self.num("n2", "n2"), Self.opt("t.alt", "p1:", ["≠p2", "<p2", ">p2"]), Self.calcDraw]
        case .zInterval:
            return [Self.inpt, Self.num("σ", "σ")] + (data ? one : [Self.num("x̄", "x̄"), Self.num("n", "n")]) + [Self.cLevel, Self.calcOnly]
        case .tInterval:
            return [Self.inpt] + (data ? one : [Self.num("x̄", "x̄"), Self.num("Sx", "Sx"), Self.num("n", "n")]) + [Self.cLevel, Self.calcOnly]
        case .twoSampZInt:
            return [Self.inpt, Self.num("σ1", "σ1"), Self.num("σ2", "σ2")]
                + (data ? two : [Self.num("x̄1", "x̄1"), Self.num("n1", "n1"), Self.num("x̄2", "x̄2"), Self.num("n2", "n2")]) + [Self.cLevel, Self.calcOnly]
        case .twoSampTInt:
            return [Self.inpt] + (data ? two : [Self.num("x̄1", "x̄1"), Self.num("Sx1", "Sx1"), Self.num("n1", "n1"), Self.num("x̄2", "x̄2"), Self.num("Sx2", "Sx2"), Self.num("n2", "n2")])
                + [Self.cLevel, Self.pooled, Self.calcOnly]
        case .onePropZInt:
            return [Self.num("x", "x"), Self.num("n", "n"), Self.cLevel, Self.calcOnly]
        case .twoPropZInt:
            return [Self.num("x1", "x1"), Self.num("n1", "n1"), Self.num("x2", "x2"), Self.num("n2", "n2"), Self.cLevel, Self.calcOnly]
        case .chi2Test:
            return [Self.opt("t.Obs", "Observed:", Self.matNames), Self.opt("t.Exp", "Expected:", Self.matNames), Self.calcDraw]
        case .chi2GOF:
            return [Self.list("Obs", "Observed:"), Self.list("ExpL", "Expected:"), Self.num("df", "df"), Self.calcDraw]
        case .twoSampFTest:
            return [Self.inpt] + (data ? two : [Self.num("Sx1", "Sx1"), Self.num("n1", "n1"), Self.num("Sx2", "Sx2"), Self.num("n2", "n2")])
                + [Self.opt("t.alt", "σ1:", ["≠σ2", "<σ2", ">σ2"]), Self.calcDraw]
        case .linRegTTest:
            return [Self.list("Xlist", "Xlist:"), Self.list("Ylist", "Ylist:"), Self.num("Freq", "Freq"), Self.opt("t.alt", "β&ρ:", ["≠0", "<0", ">0"]), Self.calcOnly]
        case .linRegTInt:
            return [Self.list("Xlist", "Xlist:"), Self.list("Ylist", "Ylist:"), Self.num("Freq", "Freq"), Self.cLevel, Self.calcOnly]
        }
    }

    // MARK: - Calculation

    struct Result {
        var lines: [String]
        var values: [(String, Double)]
        /// Distribution to shade for DRAW: kind, params, lower, upper.
        var draw: (String, [Double], Double, Double)?
    }

    func run(store: VariableStore) throws -> Result {
        let data = store.options["t.Inpt", default: 0] == 0
        let alt = store.options["t.alt", default: 0]
        func num(_ k: String) -> Double { store.numbers["t." + k] ?? 0 }
        func list(_ k: String) throws -> [Double] {
            let name = Self.listNames[min(5, store.options["t." + k, default: 0])]
            let l = store.lists[name] ?? []
            guard !l.isEmpty else { throw CalcError.dimMismatch }
            return l
        }
        func summary(_ l: [Double]) throws -> (mean: Double, sd: Double, n: Double) {
            let n = Double(l.count)
            let mean = l.reduce(0, +) / n
            let sd = l.count > 1 ? try Stats.stdDev(l, sample: true) : 0
            return (mean, sd, n)
        }
        func fmt(_ v: Double) -> String { ResultFormatter.number(v) }
        func phi(_ z: Double) -> Double { Stats.normalCDF(-1e99, z, 0, 1) }
        func pNormal(_ z: Double) -> Double {
            switch alt { case 1: return phi(z); case 2: return 1 - phi(z); default: return 2 * (1 - phi(abs(z))) }
        }
        func pT(_ t: Double, _ df: Double) -> Double {
            switch alt { case 1: return Stats.tCDF(-200, t, df); case 2: return Stats.tCDF(t, 200, df); default: return 2 * Stats.tCDF(abs(t), 200, df) }
        }
        func altLine(_ lhs: String, _ rhs: String) -> String {
            " " + lhs + ["≠", "<", ">"][min(2, alt)] + rhs
        }
        func tail(_ kind: String, _ params: [Double], _ stat: Double) -> (String, [Double], Double, Double) {
            switch alt {
            case 1: return (kind, params, -1e99, stat)
            case 2: return (kind, params, stat, 1e99)
            default: return (kind, params, abs(stat), 1e99)
            }
        }
        let level = store.numbers["t.C-Level"] ?? 0.95
        guard level > 0, level < 1 else { throw CalcError.domain }
        let zCrit = Stats.invNorm(1 - (1 - level) / 2)

        switch self {
        case .zTest:
            let mu0 = num("μ0"), sigma = num("σ")
            let (mean, sx, n): (Double, Double, Double) = data ? try summary(try list("List")) : (num("x̄"), 0, num("n"))
            guard sigma > 0, n > 0 else { throw CalcError.domain }
            let z = (mean - mu0) / (sigma / sqrt(n))
            let p = pNormal(z)
            var lines = [title, altLine("μ", fmt(mu0)), " z=\(fmt(z))", " p=\(fmt(p))", " x̄=\(fmt(mean))"]
            if data { lines.append(" Sx=\(fmt(sx))") }
            lines.append(" n=\(fmt(n))")
            return Result(lines: lines, values: [("z", z), ("p", p), ("x̄", mean), ("n", n)], draw: tail("norm", [0, 1], z))
        case .tTest:
            let mu0 = num("μ0")
            let (mean, sx, n): (Double, Double, Double) = data ? try summary(try list("List")) : (num("x̄"), num("Sx"), num("n"))
            guard sx > 0, n > 1 else { throw CalcError.domain }
            let t = (mean - mu0) / (sx / sqrt(n))
            let df = n - 1
            let p = pT(t, df)
            let lines = [title, altLine("μ", fmt(mu0)), " t=\(fmt(t))", " p=\(fmt(p))", " df=\(fmt(df))", " x̄=\(fmt(mean))", " Sx=\(fmt(sx))", " n=\(fmt(n))"]
            return Result(lines: lines, values: [("t", t), ("p", p), ("df", df), ("x̄", mean), ("Sx", sx), ("n", n)], draw: tail("t", [df], t))
        case .twoSampZTest:
            let s1 = num("σ1"), s2 = num("σ2")
            let a: (Double, Double, Double) = data ? try summary(try list("List1")) : (num("x̄1"), 0, num("n1"))
            let b: (Double, Double, Double) = data ? try summary(try list("List2")) : (num("x̄2"), 0, num("n2"))
            guard s1 > 0, s2 > 0, a.2 > 0, b.2 > 0 else { throw CalcError.domain }
            let z = (a.0 - b.0) / sqrt(s1 * s1 / a.2 + s2 * s2 / b.2)
            let p = pNormal(z)
            let lines = [title, altLine("μ1", "μ2"), " z=\(fmt(z))", " p=\(fmt(p))", " x̄1=\(fmt(a.0))", " x̄2=\(fmt(b.0))", " n1=\(fmt(a.2))", " n2=\(fmt(b.2))"]
            return Result(lines: lines, values: [("z", z), ("p", p), ("x̄1", a.0), ("x̄2", b.0), ("n1", a.2), ("n2", b.2)], draw: tail("norm", [0, 1], z))
        case .twoSampTTest:
            let a: (Double, Double, Double) = data ? try summary(try list("List1")) : (num("x̄1"), num("Sx1"), num("n1"))
            let b: (Double, Double, Double) = data ? try summary(try list("List2")) : (num("x̄2"), num("Sx2"), num("n2"))
            guard a.1 > 0, b.1 > 0, a.2 > 1, b.2 > 1 else { throw CalcError.domain }
            let pooledFlag = store.options["t.Pooled", default: 0] == 1
            let t: Double, df: Double
            var extra: [(String, Double)] = []
            if pooledFlag {
                df = a.2 + b.2 - 2
                let sp = sqrt(((a.2 - 1) * a.1 * a.1 + (b.2 - 1) * b.1 * b.1) / df)
                t = (a.0 - b.0) / (sp * sqrt(1 / a.2 + 1 / b.2))
                extra = [("Sxp", sp)]
            } else {
                let v1 = a.1 * a.1 / a.2, v2 = b.1 * b.1 / b.2
                t = (a.0 - b.0) / sqrt(v1 + v2)
                df = pow(v1 + v2, 2) / (v1 * v1 / (a.2 - 1) + v2 * v2 / (b.2 - 1))
            }
            let p = pT(t, df)
            var lines = [title, altLine("μ1", "μ2"), " t=\(fmt(t))", " p=\(fmt(p))", " df=\(fmt(df))", " x̄1=\(fmt(a.0))", " x̄2=\(fmt(b.0))", " Sx1=\(fmt(a.1))", " Sx2=\(fmt(b.1))"]
            if let sp = extra.first { lines.append(" Sxp=\(fmt(sp.1))") }
            return Result(lines: lines, values: [("t", t), ("p", p), ("df", df), ("x̄1", a.0), ("x̄2", b.0), ("Sx1", a.1), ("Sx2", b.1), ("n1", a.2), ("n2", b.2)] + extra, draw: tail("t", [df], t))
        case .onePropZTest:
            let p0 = num("p0"), x = num("x"), n = num("n")
            guard p0 > 0, p0 < 1, n > 0, x >= 0, x <= n else { throw CalcError.domain }
            let phat = x / n
            let z = (phat - p0) / sqrt(p0 * (1 - p0) / n)
            let p = pNormal(z)
            let lines = [title, altLine("prop", fmt(p0)), " z=\(fmt(z))", " p=\(fmt(p))", " p̂=\(fmt(phat))", " n=\(fmt(n))"]
            return Result(lines: lines, values: [("z", z), ("p", p), ("p̂", phat), ("n", n)], draw: tail("norm", [0, 1], z))
        case .twoPropZTest:
            let x1 = num("x1"), n1 = num("n1"), x2 = num("x2"), n2 = num("n2")
            guard n1 > 0, n2 > 0, x1 >= 0, x2 >= 0, x1 <= n1, x2 <= n2 else { throw CalcError.domain }
            let p1 = x1 / n1, p2 = x2 / n2, pp = (x1 + x2) / (n1 + n2)
            guard pp > 0, pp < 1 else { throw CalcError.domain }
            let z = (p1 - p2) / sqrt(pp * (1 - pp) * (1 / n1 + 1 / n2))
            let p = pNormal(z)
            let lines = [title, altLine("p1", "p2"), " z=\(fmt(z))", " p=\(fmt(p))", " p̂1=\(fmt(p1))", " p̂2=\(fmt(p2))", " p̂=\(fmt(pp))", " n1=\(fmt(n1))", " n2=\(fmt(n2))"]
            return Result(lines: lines, values: [("z", z), ("p", p), ("p̂1", p1), ("p̂2", p2), ("p̂", pp), ("n1", n1), ("n2", n2)], draw: tail("norm", [0, 1], z))
        case .zInterval:
            let sigma = num("σ")
            let (mean, sx, n): (Double, Double, Double) = data ? try summary(try list("List")) : (num("x̄"), 0, num("n"))
            guard sigma > 0, n > 0 else { throw CalcError.domain }
            let e = zCrit * sigma / sqrt(n)
            var lines = [title, " (\(fmt(mean - e)),\(fmt(mean + e)))", " x̄=\(fmt(mean))"]
            if data { lines.append(" Sx=\(fmt(sx))") }
            lines.append(" n=\(fmt(n))")
            return Result(lines: lines, values: [("lower", mean - e), ("upper", mean + e), ("x̄", mean), ("n", n)], draw: nil)
        case .tInterval:
            let (mean, sx, n): (Double, Double, Double) = data ? try summary(try list("List")) : (num("x̄"), num("Sx"), num("n"))
            guard sx > 0, n > 1 else { throw CalcError.domain }
            let e = Stats.invT(1 - (1 - level) / 2, n - 1) * sx / sqrt(n)
            let lines = [title, " (\(fmt(mean - e)),\(fmt(mean + e)))", " x̄=\(fmt(mean))", " Sx=\(fmt(sx))", " n=\(fmt(n))"]
            return Result(lines: lines, values: [("lower", mean - e), ("upper", mean + e), ("x̄", mean), ("Sx", sx), ("n", n), ("df", n - 1)], draw: nil)
        case .twoSampZInt:
            let s1 = num("σ1"), s2 = num("σ2")
            let a: (Double, Double, Double) = data ? try summary(try list("List1")) : (num("x̄1"), 0, num("n1"))
            let b: (Double, Double, Double) = data ? try summary(try list("List2")) : (num("x̄2"), 0, num("n2"))
            guard s1 > 0, s2 > 0, a.2 > 0, b.2 > 0 else { throw CalcError.domain }
            let d = a.0 - b.0
            let e = zCrit * sqrt(s1 * s1 / a.2 + s2 * s2 / b.2)
            let lines = [title, " (\(fmt(d - e)),\(fmt(d + e)))", " x̄1=\(fmt(a.0))", " x̄2=\(fmt(b.0))", " n1=\(fmt(a.2))", " n2=\(fmt(b.2))"]
            return Result(lines: lines, values: [("lower", d - e), ("upper", d + e), ("x̄1", a.0), ("x̄2", b.0), ("n1", a.2), ("n2", b.2)], draw: nil)
        case .twoSampTInt:
            let a: (Double, Double, Double) = data ? try summary(try list("List1")) : (num("x̄1"), num("Sx1"), num("n1"))
            let b: (Double, Double, Double) = data ? try summary(try list("List2")) : (num("x̄2"), num("Sx2"), num("n2"))
            guard a.1 > 0, b.1 > 0, a.2 > 1, b.2 > 1 else { throw CalcError.domain }
            let pooledFlag = store.options["t.Pooled", default: 0] == 1
            let df: Double, se: Double
            if pooledFlag {
                df = a.2 + b.2 - 2
                let sp = sqrt(((a.2 - 1) * a.1 * a.1 + (b.2 - 1) * b.1 * b.1) / df)
                se = sp * sqrt(1 / a.2 + 1 / b.2)
            } else {
                let v1 = a.1 * a.1 / a.2, v2 = b.1 * b.1 / b.2
                se = sqrt(v1 + v2)
                df = pow(v1 + v2, 2) / (v1 * v1 / (a.2 - 1) + v2 * v2 / (b.2 - 1))
            }
            let d = a.0 - b.0
            let e = Stats.invT(1 - (1 - level) / 2, df) * se
            let lines = [title, " (\(fmt(d - e)),\(fmt(d + e)))", " df=\(fmt(df))", " x̄1=\(fmt(a.0))", " x̄2=\(fmt(b.0))", " Sx1=\(fmt(a.1))", " Sx2=\(fmt(b.1))", " n1=\(fmt(a.2))", " n2=\(fmt(b.2))"]
            return Result(lines: lines, values: [("lower", d - e), ("upper", d + e), ("df", df), ("x̄1", a.0), ("x̄2", b.0), ("Sx1", a.1), ("Sx2", b.1), ("n1", a.2), ("n2", b.2)], draw: nil)
        case .onePropZInt:
            let x = num("x"), n = num("n")
            guard n > 0, x >= 0, x <= n else { throw CalcError.domain }
            let phat = x / n
            let e = zCrit * sqrt(phat * (1 - phat) / n)
            let lines = [title, " (\(fmt(phat - e)),\(fmt(phat + e)))", " p̂=\(fmt(phat))", " n=\(fmt(n))"]
            return Result(lines: lines, values: [("lower", phat - e), ("upper", phat + e), ("p̂", phat), ("n", n)], draw: nil)
        case .twoPropZInt:
            let x1 = num("x1"), n1 = num("n1"), x2 = num("x2"), n2 = num("n2")
            guard n1 > 0, n2 > 0, x1 >= 0, x2 >= 0, x1 <= n1, x2 <= n2 else { throw CalcError.domain }
            let p1 = x1 / n1, p2 = x2 / n2
            let d = p1 - p2
            let e = zCrit * sqrt(p1 * (1 - p1) / n1 + p2 * (1 - p2) / n2)
            let lines = [title, " (\(fmt(d - e)),\(fmt(d + e)))", " p̂1=\(fmt(p1))", " p̂2=\(fmt(p2))", " n1=\(fmt(n1))", " n2=\(fmt(n2))"]
            return Result(lines: lines, values: [("lower", d - e), ("upper", d + e), ("p̂1", p1), ("p̂2", p2), ("n1", n1), ("n2", n2)], draw: nil)
        case .chi2Test:
            let obsName = String(Self.matNames[min(9, store.options["t.Obs", default: 0])].dropFirst().dropLast())
            let expName = String(Self.matNames[min(9, store.options["t.Exp", default: 1])].dropFirst().dropLast())
            guard let obs = store.matrices[obsName] else { throw CalcError.undefined }
            let (r, c) = Matrix.dims(obs)
            guard r >= 2, c >= 2 else { throw CalcError.invalidDim }
            let rowSums = obs.map { $0.reduce(0, +) }
            let colSums = (0..<c).map { j in obs.reduce(0) { $0 + $1[j] } }
            let total = rowSums.reduce(0, +)
            guard total > 0 else { throw CalcError.domain }
            let expected = (0..<r).map { i in (0..<c).map { j in rowSums[i] * colSums[j] / total } }
            store.matrices[expName] = expected
            var chi2 = 0.0
            for i in 0..<r { for j in 0..<c where expected[i][j] > 0 { chi2 += pow(obs[i][j] - expected[i][j], 2) / expected[i][j] } }
            let df = Double((r - 1) * (c - 1))
            let p = max(0, 1 - Stats.chi2CDF(0, chi2, df))
            let lines = [title, " χ²=\(fmt(chi2))", " p=\(fmt(p))", " df=\(fmt(df))"]
            return Result(lines: lines, values: [("χ²", chi2), ("p", p), ("df", df)], draw: ("chi2", [df], chi2, 1e99))
        case .chi2GOF:
            let obs = try list("Obs"), exp = try list("ExpL")
            guard obs.count == exp.count, exp.allSatisfy({ $0 > 0 }) else { throw CalcError.dimMismatch }
            let df = num("df") > 0 ? num("df") : Double(obs.count - 1)
            let contrib = zip(obs, exp).map { pow($0 - $1, 2) / $1 }
            let chi2 = contrib.reduce(0, +)
            let p = max(0, 1 - Stats.chi2CDF(0, chi2, df))
            store.lists["L3"] = contrib
            let lines = [title, " χ²=\(fmt(chi2))", " p=\(fmt(p))", " df=\(fmt(df))", " CNTRB={\(contrib.prefix(3).map(fmt).joined(separator: " "))…"]
            return Result(lines: lines, values: [("χ²", chi2), ("p", p), ("df", df)], draw: ("chi2", [df], chi2, 1e99))
        case .twoSampFTest:
            let a: (Double, Double, Double) = data ? try summary(try list("List1")) : (0, num("Sx1"), num("n1"))
            let b: (Double, Double, Double) = data ? try summary(try list("List2")) : (0, num("Sx2"), num("n2"))
            guard a.1 > 0, b.1 > 0, a.2 > 1, b.2 > 1 else { throw CalcError.domain }
            let f = (a.1 * a.1) / (b.1 * b.1)
            let d1 = a.2 - 1, d2 = b.2 - 1
            let lowerTail = Stats.fCDF(0, f, d1, d2)
            let p: Double
            switch alt {
            case 1: p = lowerTail
            case 2: p = 1 - lowerTail
            default: p = 2 * min(lowerTail, 1 - lowerTail)
            }
            let lines = [title, altLine("σ1", "σ2"), " F=\(fmt(f))", " p=\(fmt(p))", " Sx1=\(fmt(a.1))", " Sx2=\(fmt(b.1))", " n1=\(fmt(a.2))", " n2=\(fmt(b.2))"]
            let draw: (String, [Double], Double, Double) = alt == 1 ? ("F", [d1, d2], 0, f) : ("F", [d1, d2], f, 1e99)
            return Result(lines: lines, values: [("F", f), ("p", p), ("Sx1", a.1), ("Sx2", b.1), ("n1", a.2), ("n2", b.2)], draw: draw)
        case .linRegTTest, .linRegTInt:
            let x = try list("Xlist"), y = try list("Ylist")
            guard x.count == y.count, x.count >= 3 else { throw CalcError.dimMismatch }
            let reg = try Stats.linReg(x, y)
            let n = Double(x.count), df = n - 2
            let residuals = zip(x, y).map { $0.1 - (reg.a * $0.0 + reg.b) }
            let s = sqrt(residuals.reduce(0) { $0 + $1 * $1 } / df)
            let mx = x.reduce(0, +) / n
            let sxx = x.reduce(0) { $0 + ($1 - mx) * ($1 - mx) }
            let seSlope = s / sqrt(sxx)
            store.regEQ = "\(fmt(reg.b))+\(fmt(reg.a))X"
            store.stats["a"] = reg.b; store.stats["b"] = reg.a; store.stats["r"] = reg.r; store.stats["r²"] = reg.r * reg.r
            if self == .linRegTTest {
                let t = reg.a / seSlope
                let p = pT(t, df)
                let lines = [title, " y=a+bx", altLine("β", "0 and ρ") , " t=\(fmt(t))", " p=\(fmt(p))", " df=\(fmt(df))", " a=\(fmt(reg.b))", " b=\(fmt(reg.a))", " s=\(fmt(s))", " r²=\(fmt(reg.r * reg.r))", " r=\(fmt(reg.r))"]
                return Result(lines: lines, values: [("t", t), ("p", p), ("df", df), ("s", s)], draw: nil)
            } else {
                let e = Stats.invT(1 - (1 - level) / 2, df) * seSlope
                let lines = [title, " y=a+bx", " (\(fmt(reg.a - e)),\(fmt(reg.a + e)))", " b=\(fmt(reg.a))", " df=\(fmt(df))", " s=\(fmt(s))", " a=\(fmt(reg.b))", " r²=\(fmt(reg.r * reg.r))", " r=\(fmt(reg.r))"]
                return Result(lines: lines, values: [("lower", reg.a - e), ("upper", reg.a + e), ("df", df), ("s", s)], draw: nil)
            }
        }
    }
}
