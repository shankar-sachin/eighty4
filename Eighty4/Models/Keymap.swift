import Foundation

/// The full TI-84 Plus CE keypad: primary | 2nd (blue) | alpha (green).
enum Keymap {
    private typealias Row = [(KeyID, String, String?, String?, KeyStyle)]

    private static let rows: [Row] = [
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

    static let keys: [KeySpec] = {
        var out: [KeySpec] = []
        for (r, row) in rows.enumerated() {
            for (c, k) in row.enumerated() {
                out.append(KeySpec(id: k.0, primary: k.1, second: k.2, alpha: k.3, style: k.4, row: r + 1, col: c + 1))
            }
        }
        return out
    }()

    static let byID: [KeyID: KeySpec] = Dictionary(uniqueKeysWithValues: keys.map { ($0.id, $0) })

    static func spec(_ id: KeyID) -> KeySpec? { byID[id] }
}
