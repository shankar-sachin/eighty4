import Foundation

enum Token: Equatable {
    case number(Double)
    case string(String)
    case op(BinaryOp)
    case negate                // TI "(−)" glyph ⁻
    case postfix(String)       // ² ³ ⁻¹ ! ° ʳ ' ᵀ ▶Frac ▶Dec ▶DMS ▶F◀▶D
    case lparen, rparen, lbrace, rbrace, lbracket, rbracket, comma, store
    case function(String)      // name without the "("
    case nullary(String)       // rand
    case pi, e, ans
    case variable(String)      // A–Z θ a b c d r n, window/stat variables
    case listVar(String)       // "L1"
    case matVar(String)        // "A"
    case yVar(Int)             // 0...9
    case command(String)

    var startsPrimary: Bool {
        switch self {
        case .number, .string, .lparen, .lbrace, .lbracket, .function, .nullary,
             .pi, .e, .ans, .variable, .listVar, .matVar, .yVar:
            return true
        default:
            return false
        }
    }
}

enum Tokenizer {
    static let subscripts = ["₀", "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉"]

    static let windowVars = ["Xmin", "Xmax", "Xscl", "Ymin", "Ymax", "Yscl", "Xres",
                             "TblStart", "ΔTbl", "XFact", "YFact"]
    static let statVars = ["x̄", "Σx", "Σx²", "Sx", "σx", "ȳ", "Σy", "Σy²", "Sy", "σy", "Σxy",
                           "minX", "maxX", "minY", "maxY", "Q1", "Med", "Q3", "r²", "n"]
    static let commands = ["ClrHome", "ClrDraw", "ClrAllLists", "ClrList", "PlotsOff", "PlotsOn",
                           "Degree", "Radian", "Float", "Fix", "Normal", "Sci", "Eng",
                           "FnOn", "FnOff", "AxesOn", "AxesOff", "GridOn", "GridOff", "GridDot", "GridLine",
                           "CoordOn", "CoordOff", "LabelOn", "LabelOff", "ExprOn", "ExprOff",
                           "ZStandard", "ZDecimal", "ZSquare", "ZTrig", "ZInteger", "ZoomStat", "ZoomFit",
                           "ZPrevious", "ZoomSto", "ZoomRcl", "ZoomIn", "ZoomOut", "ZQuadrant1",
                           "Connected", "Dot", "Sequential", "Simul", "Real", "Full", "Horiz", "G-T",
                           "Clear Entries", "DiagnosticOn", "DiagnosticOff", "SetUpEditor",
                           "Horizontal", "Vertical", "DrawF", "ClrTable"]
    static let postfixes = ["⁻¹", "▶Frac", "▶Dec", "▶DMS", "▶F◀▶D", "▶Rect", "▶Polar", "▶n/d◀▶Un/d"]

    /// Multi-character symbols, longest first, as character arrays for allocation-free matching.
    private static let symbols: [([Character], Token)] = {
        var s: [(String, Token)] = []
        for name in Functions.allNames { s.append((name + "(", .function(name))) }
        for p in postfixes { s.append((p, .postfix(p))) }
        s += [("nCr", .op(.nCr)), ("nPr", .op(.nPr)), ("and", .op(.and)), ("xor", .op(.xor)),
              ("or", .op(.or)), ("ˣ√", .op(.nthRoot)), ("≠", .op(.ne)), ("≥", .op(.ge)), ("≤", .op(.le))]
        s += [("Ans", .ans), ("rand", .nullary("rand"))]
        for i in 1...6 { s.append(("L\(subscripts[i])", .listVar("L\(i)"))) }
        for i in 0...9 { s.append(("Y\(subscripts[i])", .yVar(i))) }
        for v in windowVars + statVars { s.append((v, .variable(v))) }
        for c in commands { s.append((c, .command(c))) }
        return s.sorted { $0.0.count > $1.0.count }.map { (Array($0.0), $0.1) }
    }()

    static func tokenize(_ text: String) throws -> [Token] {
        let chars = Array(text)
        var i = 0
        var out: [Token] = []

        func isDigit(_ c: Character) -> Bool { c.isASCII && c.isNumber }

        while i < chars.count {
            let c = chars[i]
            if c == " " && !(out.last.map { if case .command = $0 { return true } else { return false } } ?? false) {
                i += 1; continue
            }
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

            // Matrix names: [A] … [J]
            if c == "[", i + 2 < chars.count, chars[i + 1].isASCII, chars[i + 1].isUppercase, chars[i + 2] == "]" {
                out.append(.matVar(String(chars[i + 1])))
                i += 3
                continue
            }

            // Strings
            if c == "\"" {
                var j = i + 1
                var s = ""
                while j < chars.count, chars[j] != "\"" { s.append(chars[j]); j += 1 }
                out.append(.string(s))
                i = min(chars.count, j + 1)
                continue
            }

            // Multi-character symbols.
            var matched = false
            for (sym, tok) in symbols where sym.count <= chars.count - i {
                if chars[i..<(i + sym.count)].elementsEqual(sym) {
                    out.append(tok)
                    if case .function = tok { out.append(.lparen) }   // the "(" is part of the matched name
                    i += sym.count
                    matched = true
                    break
                }
            }
            if matched { continue }

            switch c {
            case "+": out.append(.op(.add))
            case "−", "-": out.append(.op(.sub))
            case "×", "*": out.append(.op(.mul))
            case "÷", "/": out.append(.op(.div))
            case "^": out.append(.op(.pow))
            case "=": out.append(.op(.eq))
            case ">": out.append(.op(.gt))
            case "<": out.append(.op(.lt))
            case "²", "³", "!", "°", "ʳ", "'", "ᵀ": out.append(.postfix(String(c)))
            case "(": out.append(.lparen)
            case ")": out.append(.rparen)
            case "{": out.append(.lbrace)
            case "}": out.append(.rbrace)
            case "[": out.append(.lbracket)
            case "]": out.append(.rbracket)
            case ",": out.append(.comma)
            case "→": out.append(.store)
            case "⁻": out.append(.negate)
            case "π": out.append(.pi)
            case "e": out.append(.e)
            case "θ": out.append(.variable("θ"))
            case "i": throw CalcError.dataType
            default:
                if c.isASCII, c.isUppercase, c.isLetter {
                    out.append(.variable(String(c)))
                } else if "abcdruvw".contains(c) {
                    out.append(.variable(String(c)))
                } else {
                    throw CalcError.syntax
                }
            }
            i += 1
        }
        return out
    }
}
