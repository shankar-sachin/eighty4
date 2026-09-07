import SwiftUI

/// Visual style of a physical key on the TI-84 Plus CE.
enum KeyStyle {
    case dark   // charcoal key, white legend (most keys)
    case white  // digits, ".", "(−)"
    case blue   // 2nd
    case green  // alpha
}

enum KeyID: String, CaseIterable, Hashable, Identifiable {
    case yEquals, window, zoom, trace, graph
    case second, mode, del
    case alpha, xtn, stat
    case math, apps, prgm, vars, clear
    case inverse, sin, cos, tan, power
    case square, comma, lparen, rparen, divide
    case log, seven, eight, nine, multiply
    case ln, four, five, six, minus
    case sto, one, two, three, plus
    case on, zero, dot, negate, enter
    case up, down, left, right

    var id: String { rawValue }
}

struct KeySpec: Identifiable {
    let id: KeyID
    let primary: String
    let second: String?
    let alpha: String?
    let style: KeyStyle
    let row: Int   // 1...10
    let col: Int   // 1...5

    /// Point size (in body design units) of the primary legend.
    var legendSize: CGFloat {
        if row == 1 { return 27 }
        switch id {
        case .xtn: return 24
        case .sto, .negate, .enter, .alpha, .clear, .second: return 29
        case .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine: return 40
        case .dot, .plus, .minus, .multiply, .divide: return 42
        case .comma: return 46
        default: return 33
        }
    }
}
