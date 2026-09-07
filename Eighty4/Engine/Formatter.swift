import Foundation

/// Formats values the way the TI-84 Plus CE does, honoring MODE (NORMAL/SCI/ENG, FLOAT/FIX n).
enum ResultFormatter {
    static func format(_ v: Value, store: VariableStore) -> String {
        format(v, notation: store.notation, fixed: store.fixedDigits, mixed: store.mixedFractions)
    }

    static func format(_ v: Value) -> String { format(v, notation: 0, fixed: nil) }

    static func format(_ v: Value, notation: Int, fixed: Int?, mixed: Bool = false) -> String {
        switch v {
        case .num(let d): return number(d, notation: notation, fixed: fixed)
        case .fraction(let n, let d):
            if d == 1 { return number(Double(n), notation: notation, fixed: fixed) }
            if mixed, abs(n) > d {
                let whole = abs(n) / d, rem = abs(n) % d
                return (n < 0 ? "⁻" : "") + "\(whole)_\(rem)/\(d)"
            }
            return (n < 0 ? "⁻" : "") + "\(abs(n))/\(d)"
        case .list(let l):
            return "{" + l.map { number($0, notation: notation, fixed: fixed) }.joined(separator: " ") + "}"
        case .matrix(let m):
            let rows = m.map { "[" + $0.map { number($0, notation: notation, fixed: fixed) }.joined(separator: " ") + "]" }
            return rows.enumerated().map { i, r in (i == 0 ? "[" : " ") + r + (i == rows.count - 1 ? "]" : "") }.joined(separator: "\n")
        case .str(let s): return s
        }
    }

    static func number(_ x: Double, notation: Int = 0, fixed: Int? = nil) -> String {
        if x == 0 {
            if let f = fixed, f > 0, notation == 0 { return "0." + String(repeating: "0", count: f) }
            return "0"
        }
        var s: String
        switch notation {
        case 1: s = sci(x, digits: fixed, engineering: false)
        case 2: s = sci(x, digits: fixed, engineering: true)
        default:
            let mag = abs(x)
            if let f = fixed {
                if mag >= 1e10 || mag < 1e-4 { s = sci(x, digits: f, engineering: false) }
                else { s = String(format: "%.\(f)f", x) }
            } else {
                s = String(format: "%.10g", x)
                if let eIdx = s.firstIndex(of: "e") {
                    let mantissa = String(s[..<eIdx])
                    var exp = String(s[s.index(after: eIdx)...])
                    var sign = ""
                    if exp.hasPrefix("+") { exp.removeFirst() }
                    else if exp.hasPrefix("-") { exp.removeFirst(); sign = "⁻" }
                    while exp.hasPrefix("0") && exp.count > 1 { exp.removeFirst() }
                    s = mantissa + "ᴇ" + sign + exp
                }
            }
        }
        if s.hasPrefix("0.") { s.removeFirst() }
        else if s.hasPrefix("-0.") { s = "-" + s.dropFirst(2) }
        if s.hasPrefix("-") { s = "⁻" + s.dropFirst() }
        if s == "⁻0" { s = "0" }
        return s
    }

    private static func sci(_ x: Double, digits: Int?, engineering: Bool) -> String {
        var exp = Int(floor(log10(abs(x))))
        if engineering { exp = Int(floor(Double(exp) / 3)) * 3 }
        var mant = x / pow(10, Double(exp))
        let limit: Double = engineering ? 1000 : 10
        if abs(mant) >= limit { mant /= limit; exp += engineering ? 3 : 1 }
        var m: String
        if let d = digits {
            m = String(format: "%.\(d)f", mant)
        } else {
            m = String(format: "%.9f", mant)
            while m.hasSuffix("0") { m.removeLast() }
            if m.hasSuffix(".") { m.removeLast() }
        }
        return m + "ᴇ" + (exp < 0 ? "⁻" : "") + "\(abs(exp))"
    }
}
