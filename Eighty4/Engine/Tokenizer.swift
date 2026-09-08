import Foundation

enum Token: Equatable {
    case number(Double)
    case string(String)
    case op(BinaryOp)
    case negate                // TI "(−)" glyph ⁻
    case postfix(String)       // ² ³ ⁻¹ ! ° ʳ ' ᵀ ▶Frac ▶Dec ▶DMS ▶F◀▶D
    case lparen, rparen, lbrace, rbrace, lbracket, rbracket, comma, store
    case function(String)      // name without the "("
    case nullary(String)       // rand getKey
    case pi, e, ans
    case imaginary             // i
    case variable(String)      // A–Z θ a b c d r n, window/stat variables
    case listVar(String)       // "L1"
    case matVar(String)        // "A"
    case yVar(Int)             // 0...9
    case namedFunc(String)     // "X1T" "Y1T" "r1"
    case strVar(Int)           // Str0…Str9
    case picVar(Int)           // Pic0…Pic9
    case gdbVar(Int)           // GDB0…GDB9
    case prgm(String)          // prgmNAME
    case command(String)
    /// MathPrint templates: ⌈n⌉/⌊d⌋ fraction and the Un/d whole-number slot in front of one.
    case fracOpen, fracSep, fracClose, mixedOpen

    var startsPrimary: Bool {
        switch self {
        case .number, .string, .lparen, .lbrace, .lbracket, .function, .nullary,
             .pi, .e, .ans, .imaginary, .variable, .listVar, .matVar, .yVar, .namedFunc, .strVar, .fracOpen, .mixedOpen:
            return true
        default:
            return false
        }
    }
}

enum Tokenizer {
    static let subscripts = ["₀", "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉"]

    static let windowVars = ["Xmin", "Xmax", "Xscl", "Ymin", "Ymax", "Yscl", "Xres",
                             "Tmin", "Tmax", "Tstep", "θmin", "θmax", "θstep",
                             "nMin", "nMax", "PlotStart", "PlotStep",
                             "TblStart", "ΔTbl", "XFact", "YFact"]
    static let statVars = ["x̄", "Σx", "Σx²", "Sx", "σx", "ȳ", "Σy", "Σy²", "Sy", "σy", "Σxy",
                           "minX", "maxX", "minY", "maxY", "Q1", "Med", "Q3", "r²", "n",
                           "x̄1", "x̄2", "Sx1", "Sx2", "Sxp", "n1", "n2", "p̂", "p̂1", "p̂2",
                           "df", "lower", "upper", "z", "t", "p", "s"]
    static let commands = ["ClrHome", "ClrDraw", "ClrAllLists", "ClrList", "PlotsOff", "PlotsOn",
                           "Degree", "Radian", "Float", "Fix", "Normal", "Sci", "Eng",
                           "FnOn", "FnOff", "AxesOn", "AxesOff", "GridOn", "GridOff", "GridDot", "GridLine",
                           "CoordOn", "CoordOff", "LabelOn", "LabelOff", "ExprOn", "ExprOff",
                           "ZStandard", "ZDecimal", "ZSquare", "ZTrig", "ZInteger", "ZoomStat", "ZoomFit",
                           "ZPrevious", "ZoomSto", "ZoomRcl", "ZoomIn", "ZoomOut", "ZQuadrant1",
                           "ZFrac1/2", "ZFrac1/3", "ZFrac1/4",
                           "Connected", "Dot", "Sequential", "Simul", "Real", "a+bi", "re^θi", "Full", "Horiz", "G-T",
                           "Clear Entries", "DiagnosticOn", "DiagnosticOff", "SetUpEditor",
                           "Horizontal", "Vertical", "DrawF", "DrawInv", "ClrTable",
                           "StorePic", "RecallPic", "StoreGDB", "RecallGDB", "BackgroundOn", "BackgroundOff",
                           "Func", "Param", "Polar", "Seq"]
    /// TI-BASIC keywords handled by the program runner (also listed in CATALOG).
    static let programCommands = ["Disp", "Input", "Prompt", "Output(", "Pause", "If", "Then", "Else", "For(",
                                  "While", "Repeat", "End", "Lbl", "Goto", "Menu(", "Return", "Stop", "DelVar",
                                  "IS>(", "DS<(", "DispGraph", "DispTable", "Wait"]
    static let postfixes = ["⁻¹", "▶Frac", "▶Dec", "▶DMS", "▶F◀▶D", "▶Rect", "▶Polar", "▶n/d◀▶Un/d"]
    static let nullaries = ["rand", "getKey"]

    static func namedFuncLabel(_ key: String) -> String {
        // "X1T" → "X₁T", "r1" → "r₁"
        var out = ""
        for ch in key {
            if let d = ch.wholeNumberValue, ch.isASCII { out += subscripts[d] } else { out.append(ch) }
        }
        return out
    }

    /// Multi-character symbols, longest first, as character arrays for allocation-free matching.
    private static let symbols: [([Character], Token)] = {
        var s: [(String, Token)] = []
        for name in Functions.allNames { s.append((name + "(", .function(name))) }
        for p in postfixes { s.append((p, .postfix(p))) }
        s += [("nCr", .op(.nCr)), ("nPr", .op(.nPr)), ("and", .op(.and)), ("xor", .op(.xor)),
              ("or", .op(.or)), ("ˣ√", .op(.nthRoot)), ("≠", .op(.ne)), ("≥", .op(.ge)), ("≤", .op(.le))]
        s += [("Ans", .ans)]
        for n in nullaries { s.append((n, .nullary(n))) }
        for i in 1...6 { s.append(("L\(subscripts[i])", .listVar("L\(i)"))) }
        for i in 0...9 { s.append(("Y\(subscripts[i])", .yVar(i))) }
        for i in 1...6 {
            s.append(("X\(subscripts[i])T", .namedFunc("X\(i)T")))
            s.append(("Y\(subscripts[i])T", .namedFunc("Y\(i)T")))
            s.append(("r\(subscripts[i])", .namedFunc("r\(i)")))
        }
        for i in 0...9 {
            s.append(("Str\(i)", .strVar(i)))
            s.append(("Pic\(i)", .picVar(i)))
            s.append(("GDB\(i)", .gdbVar(i)))
        }
        for v in windowVars + statVars { s.append((v, .variable(v))) }
        for c in commands { s.append((c, .command(c))) }
        return s.sorted { $0.0.count > $1.0.count }.map { (Array($0.0), $0.1) }
    }()

    // MARK: - Display tokens (cursor movement, DEL, overwrite)

    /// Symbols the entry line treats as one unit. Ones that start with a digit ("10^(") are left
    /// out so digits typed one at a time never fuse into a token.
    private static let displaySymbols: [[Character]] = symbols.map { $0.0 }.filter { !($0.first?.isNumber ?? false) }

    /// Length of the display token that starts at `i` (1 for a plain character).
    static func displayTokenLength(in chars: [Character], at i: Int) -> Int {
        for sym in displaySymbols where sym.count <= chars.count - i {
            if chars[i..<(i + sym.count)].elementsEqual(sym) { return sym.count }
        }
        return 1
    }

    /// Range of the display token containing `pos`; an empty range at the end when `pos` is past the text.
    static func displayTokenRange(in chars: [Character], containing pos: Int) -> Range<Int> {
        var i = 0
        while i < chars.count {
            let n = displayTokenLength(in: chars, at: i)
            if pos < i + n { return i..<(i + n) }
            i += n
        }
        return chars.count..<chars.count
    }

    static func tokenize(_ text: String) throws -> [Token] {
        // Function-style MathPrint templates (exponent, √, Σ …) tokenize as their flat calls.
        let chars = Array(MathPrint.flatten(text))
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

            // Program names: prgmNAME
            if c == "p", i + 4 <= chars.count, String(chars[i..<(i + 4)]) == "prgm" {
                var j = i + 4
                var name = ""
                while j < chars.count, chars[j].isASCII, chars[j].isLetter || chars[j].isNumber, name.count < 8 {
                    name.append(chars[j]); j += 1
                }
                guard !name.isEmpty else { throw CalcError.syntax }
                out.append(.prgm(name))
                i = j
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
            case "_": out.append(.op(.mixed))
            case "²", "³", "!", "°", "ʳ", "'", "ᵀ", "%": out.append(.postfix(String(c)))
            case "(": out.append(.lparen)
            case ")": out.append(.rparen)
            case "{": out.append(.lbrace)
            case "}": out.append(.rbrace)
            case "[": out.append(.lbracket)
            case "]": out.append(.rbracket)
            case ",": out.append(.comma)
            case "→": out.append(.store)
            case "⁻": out.append(.negate)
            case MathPrint.fracOpen: out.append(.fracOpen)
            case MathPrint.fracSep: out.append(.fracSep)
            case MathPrint.fracClose: out.append(.fracClose)
            case MathPrint.mixedOpen: out.append(.mixedOpen)
            case MathPrint.stackOpen: out.append(.function("piecewise")); out.append(.lparen)
            case MathPrint.rowSep, MathPrint.colSep: out.append(.comma)
            case MathPrint.stackClose: out.append(.rparen)
            case "π": out.append(.pi)
            case "e": out.append(.e)
            case "θ": out.append(.variable("θ"))
            case "i": out.append(.imaginary)
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
