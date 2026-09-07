import Foundation

enum Token: Equatable {
    case number(Double)
    case plus, minus, times, divide, power
    case negate          // TI "(−)" glyph ⁻
    case square, inverse // postfix ² and ⁻¹
    case lparen, rparen
    case function(String) // sin cos tan asin acos atan log ln sqrt abs
    case pi, e, ans
    case variable(Character)

    /// True if this token can begin a primary expression (used for implicit multiplication).
    var startsPrimary: Bool {
        switch self {
        case .number, .lparen, .function, .pi, .e, .ans, .variable: return true
        default: return false
        }
    }
}

enum Tokenizer {
    private static let functions: [(String, String)] = [
        ("sin⁻¹(", "asin"), ("cos⁻¹(", "acos"), ("tan⁻¹(", "atan"),
        ("sin(", "sin"), ("cos(", "cos"), ("tan(", "tan"),
        ("log(", "log"), ("abs(", "abs"), ("ln(", "ln"), ("√(", "sqrt"),
    ]

    static func tokenize(_ text: String) throws -> [Token] {
        let chars = Array(text)
        var i = 0
        var out: [Token] = []

        func isDigit(_ c: Character) -> Bool { c.isASCII && c.isNumber }

        while i < chars.count {
            let c = chars[i]

            if c == " " { i += 1; continue }

            // Numbers: digits, optional ".", optional ᴇ exponent.
            if isDigit(c) || c == "." {
                var j = i
                var str = ""
                while j < chars.count, isDigit(chars[j]) || chars[j] == "." {
                    str.append(chars[j]); j += 1
                }
                if j < chars.count, chars[j] == "ᴇ" {
                    var k = j + 1
                    var exp = ""
                    if k < chars.count, chars[k] == "⁻" || chars[k] == "−" { exp = "-"; k += 1 }
                    var digits = ""
                    while k < chars.count, isDigit(chars[k]) { digits.append(chars[k]); k += 1 }
                    if digits.isEmpty { throw CalcError.syntax }
                    str += "e" + exp + digits
                    j = k
                }
                guard str != ".", let v = Double(str) else { throw CalcError.syntax }
                out.append(.number(v))
                i = j
                continue
            }

            // Multi-character function names.
            var matched = false
            for (prefix, name) in functions {
                let p = Array(prefix)
                if i + p.count <= chars.count, Array(chars[i..<(i + p.count)]) == p {
                    out.append(.function(name))
                    out.append(.lparen)
                    i += p.count
                    matched = true
                    break
                }
            }
            if matched { continue }

            if i + 3 <= chars.count, Array(chars[i..<(i + 3)]) == Array("Ans") {
                out.append(.ans); i += 3; continue
            }

            if c == "⁻" {
                if i + 1 < chars.count, chars[i + 1] == "¹" {
                    out.append(.inverse); i += 2
                } else {
                    out.append(.negate); i += 1
                }
                continue
            }

            switch c {
            case "+": out.append(.plus)
            case "−", "-": out.append(.minus)
            case "×", "*": out.append(.times)
            case "÷", "/": out.append(.divide)
            case "^": out.append(.power)
            case "²": out.append(.square)
            case "(": out.append(.lparen)
            case ")": out.append(.rparen)
            case "π": out.append(.pi)
            case "e": out.append(.e)
            case "θ", "u", "v", "w": out.append(.variable(c))
            default:
                if c.isASCII, c.isUppercase, c.isLetter {
                    out.append(.variable(c))
                } else {
                    throw CalcError.syntax
                }
            }
            i += 1
        }
        return out
    }
}
