import Foundation

/// Formats results the way the TI-84 Plus CE does in FLOAT mode:
/// up to 10 significant digits, no leading zero (".5"), TI negation glyph, and
/// scientific notation as "1.2345ᴇ12" when |x| ≥ 1E10 or |x| < 1E-4.
enum ResultFormatter {
    static func format(_ x: Double) -> String {
        if x == 0 { return "0" }
        var s = String(format: "%.10g", x)

        if let eIdx = s.firstIndex(of: "e") {
            let mantissa = String(s[..<eIdx])
            var exp = String(s[s.index(after: eIdx)...])
            var sign = ""
            if exp.hasPrefix("+") { exp.removeFirst() }
            else if exp.hasPrefix("-") { exp.removeFirst(); sign = "⁻" }
            while exp.hasPrefix("0") && exp.count > 1 { exp.removeFirst() }
            s = mantissa + "ᴇ" + sign + exp
        }

        if s.hasPrefix("0.") { s.removeFirst() }
        else if s.hasPrefix("-0.") { s = "-" + s.dropFirst(2) }

        if s.hasPrefix("-") { s = "⁻" + s.dropFirst() }
        if s == "⁻0" { s = "0" }
        return s
    }
}
