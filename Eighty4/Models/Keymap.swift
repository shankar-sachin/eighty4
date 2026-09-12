import Foundation

/// The full keypad per model: primary | 2nd (blue) | alpha (green).
enum Keymap {
    private typealias Row = [(KeyID, String, String?, String?, KeyStyle)]

    /// TI-84 Plus CE.
    private static let ceRows: [Row] = [
        [(.yEquals, "y=", "STAT PLOT", "F1", .dark), (.window, "window", "TBLSET", "F2", .dark), (.zoom, "zoom", "FORMAT", "F3", .dark), (.trace, "trace", "CALC", "F4", .dark), (.graph, "graph", "TABLE", "F5", .dark)],
        [(.second, "2nd", nil, nil, .blue), (.mode, "mode", "QUIT", nil, .dark), (.del, "del", "INS", nil, .dark)],
        [(.alpha, "alpha", "A-LOCK", nil, .green), (.xtn, "X,T,θ,n", "LINK", nil, .dark), (.stat, "stat", "LIST", nil, .dark)],
        [(.math, "math", "TEST", "A", .dark), (.apps, "apps", "ANGLE", "B", .dark), (.prgm, "prgm", "DRAW", "C", .dark), (.vars, "vars", "DISTR", nil, .dark), (.clear, "clear", nil, nil, .dark)],
        [(.inverse, "x⁻¹", "MATRIX", "D", .dark), (.sin, "sin", "SIN⁻¹", "E", .dark), (.cos, "cos", "COS⁻¹", "F", .dark), (.tan, "tan", "TAN⁻¹", "G", .dark), (.power, "^", "π", "H", .dark)],
        [(.square, "x²", "√", "I", .dark), (.comma, ",", "EE", "J", .dark), (.lparen, "(", "{", "K", .dark), (.rparen, ")", "}", "L", .dark), (.divide, "÷", "e", "M", .dark)],
        [(.log, "log", "10ˣ", "N", .dark), (.seven, "7", "u", "O", .white), (.eight, "8", "v", "P", .white), (.nine, "9", "w", "Q", .white), (.multiply, "×", "[", "R", .dark)],
        [(.ln, "ln", "eˣ", "S", .dark), (.four, "4", "L4", "T", .white), (.five, "5", "L5", "U", .white), (.six, "6", "L6", "V", .white), (.minus, "−", "]", "W", .dark)],
        [(.sto, "sto→", "RCL", "X", .dark), (.one, "1", "L1", "Y", .white), (.two, "2", "L2", "Z", .white), (.three, "3", "L3", "θ", .white), (.plus, "+", "MEM", "\"", .dark)],
        [(.on, "on", "OFF", nil, .dark), (.zero, "0", "CATALOG", "␣", .white), (.dot, ".", "i", ":", .white), (.negate, "(−)", "ANS", "?", .white), (.enter, "enter", "ENTRY", "SOLVE", .dark)],
    ]

    /// TI-84 Evo. Big rounded keys in the shell colour with the 2nd (blue) and alpha (green) legends
    /// printed on the key itself, and black digit keys. Compared with the CE: apps became the n/d
    /// fraction template, x⁻¹ became x^□ (2nd: ⁿ√), ÷ × − + moved up one row, the old + position is the
    /// ◂▸ toggle key, 2nd+vars is matrix and alpha+stat is distr, on doubles as home, and 2nd+clear undoes
    /// a clear. The 2nd/alpha legends stay in their CE positions, so the shifted operator keys carry π e [ ].
    private static let evoRows: [Row] = [
        [(.yEquals, "Y=", "plot", "f1", .white), (.window, "window", "tblset", "f2", .white), (.zoom, "zoom", "format", "f3", .white), (.trace, "trace", "calc", "f4", .white), (.graph, "graph", "table", "f5", .white)],
        [(.second, "2nd", nil, nil, .blue), (.mode, "mode", "quit", nil, .white), (.del, "del", "|◂▸▮", nil, .white)],
        [(.alpha, "alpha", "A-lock", nil, .green), (.xtn, "X,T,θ,n", "link", nil, .white), (.stat, "stat", "list", "distr", .white)],
        [(.math, "math", "=≤≠>", "A", .white), (.fraction, "n/d", "angle", "B", .white), (.prgm, "prgm", "draw", "C", .white), (.vars, "vars", "matrix", nil, .white), (.clear, "clear", "↰clear", nil, .white)],
        [(.expTemplate, "x^□", "ⁿ√", "D", .white), (.sin, "sin", "sin⁻¹", "E", .white), (.cos, "cos", "cos⁻¹", "F", .white), (.tan, "tan", "tan⁻¹", "G", .white), (.divide, "÷", "π", "H", .white)],
        [(.square, "x²", "√", "I", .white), (.comma, ",", "EE", "J", .white), (.lparen, "(", "{", "K", .white), (.rparen, ")", "}", "L", .white), (.multiply, "×", "e", "M", .white)],
        [(.log, "log", "10ˣ", "N", .white), (.seven, "7", "u", "O", .dark), (.eight, "8", "v", "P", .dark), (.nine, "9", "w", "Q", .dark), (.minus, "−", "[", "R", .white)],
        [(.ln, "ln", "eˣ", "S", .white), (.four, "4", "L4", "T", .dark), (.five, "5", "L5", "U", .dark), (.six, "6", "L6", "V", .dark), (.plus, "+", "]", "W", .white)],
        [(.sto, "sto→", "recall", "X", .white), (.one, "1", "L1", "Y", .dark), (.two, "2", "L2", "Z", .dark), (.three, "3", "L3", "θ", .dark), (.toggle, "◂▸", "mem", "\"", .white)],
        [(.on, "on", "off", nil, .white), (.zero, "0", "catalog", "␣", .dark), (.dot, ".", "i", ":", .dark), (.negate, "(−)", "Ans", "?", .dark), (.enter, "enter", "entry", nil, .white)],
    ]

    private static func build(_ rows: [Row]) -> [KeySpec] {
        var out: [KeySpec] = []
        for (r, row) in rows.enumerated() {
            for (c, k) in row.enumerated() {
                out.append(KeySpec(id: k.0, primary: k.1, second: k.2, alpha: k.3, style: k.4, row: r + 1, col: c + 1))
            }
        }
        return out
    }

    private static let ceKeys = build(ceRows)
    private static let evoKeys = build(evoRows)
    private static let ceByID: [KeyID: KeySpec] = Dictionary(uniqueKeysWithValues: ceKeys.map { ($0.id, $0) })
    private static let evoByID: [KeyID: KeySpec] = Dictionary(uniqueKeysWithValues: evoKeys.map { ($0.id, $0) })

    /// The TI-84 Plus CE keypad.
    static let keys: [KeySpec] = ceKeys

    static func keys(for model: CalcModel) -> [KeySpec] { model == .evo ? evoKeys : ceKeys }

    static func spec(_ id: KeyID, model: CalcModel = .ce) -> KeySpec? { model == .evo ? evoByID[id] : ceByID[id] }
}
