import SwiftUI

/// PlySmlt2: polynomial root finder and simultaneous equation solver.
final class PlySmlt2App: Game {
    let title = "PLYSMLT2"
    private(set) var wantsExit = false
    let handlesClear = true

    private enum Mode { case main, polyOrder, polyCoefs, polyRoots, simulDims, simulEntry, simulResult, about }
    private var mode: Mode = .main
    private var menuRow = 0
    private let store: VariableStore

    // Polynomial
    private var order = 2
    private var coefs: [AppField] = []
    private var coefRow = 0
    private var roots: [Cx] = []

    // Simultaneous
    private var equations = 2
    private var unknowns = 2
    private var dimRow = 0
    private var cells: [[AppField]] = []
    private var cellRow = 0, cellCol = 0
    private var solution: [Double]? = nil
    private var rrefResult: [[Double]] = []

    init(store: VariableStore) { self.store = store }

    func update(now: TimeInterval) {}
    func press(_ key: KeyID) {}

    func handle(_ key: KeyID, _ action: KeyAction) {
        switch mode {
        case .main:
            if let d = AppUI.digit(action) { menuRow = d - 1; selectMain() ; return }
            switch action {
            case .up: menuRow = (menuRow + 3) % 4
            case .down: menuRow = (menuRow + 1) % 4
            case .enter: selectMain()
            case .clear: wantsExit = true
            default: break
            }
        case .about:
            if action == .clear || action == .enter || AppUI.fkey(key) != nil { mode = .main }
        case .polyOrder:
            switch action {
            case .left, .up: order = max(1, order - 1)
            case .right, .down: order = min(10, order + 1)
            case .enter: startCoefs()
            case .clear: mode = .main
            default:
                if let d = AppUI.digit(action) { order = d == 0 ? 10 : d }
                if AppUI.fkey(key) == 5 { startCoefs() }
                if AppUI.fkey(key) == 1 { mode = .main }
            }
        case .polyCoefs:
            if AppUI.fkey(key) == 5 { solvePoly(); return }
            if AppUI.fkey(key) == 1 { mode = .main; return }
            if AppUI.fkey(key) == 2 { mode = .polyOrder; return }
            switch action {
            case .up: coefRow = max(0, coefRow - 1)
            case .down, .enter: if coefRow < coefs.count - 1 { coefRow += 1 } else if action == .enter { solvePoly() }
            case .clear: coefs[coefRow].chars = []
            default: _ = coefs[coefRow].apply(action)
            }
        case .polyRoots:
            if AppUI.fkey(key) == 1 { mode = .main } else if AppUI.fkey(key) == 2 || action == .clear { mode = .polyCoefs }
        case .simulDims:
            if AppUI.fkey(key) == 5 { startCells(); return }
            if AppUI.fkey(key) == 1 { mode = .main; return }
            switch action {
            case .up, .down: dimRow = 1 - dimRow
            case .left: if dimRow == 0 { equations = max(2, equations - 1) } else { unknowns = max(2, unknowns - 1) }
            case .right: if dimRow == 0 { equations = min(10, equations + 1) } else { unknowns = min(10, unknowns + 1) }
            case .enter: if dimRow == 0 { dimRow = 1 } else { startCells() }
            case .clear: mode = .main
            default:
                if let d = AppUI.digit(action), d >= 2 { if dimRow == 0 { equations = d } else { unknowns = d } }
            }
        case .simulEntry:
            if AppUI.fkey(key) == 5 { solveSimul(); return }
            if AppUI.fkey(key) == 1 { mode = .main; return }
            if AppUI.fkey(key) == 2 { mode = .simulDims; return }
            switch action {
            case .up: cellRow = max(0, cellRow - 1)
            case .down: cellRow = min(equations - 1, cellRow + 1)
            case .left: cellCol = max(0, cellCol - 1)
            case .right: cellCol = min(unknowns, cellCol + 1)
            case .enter:
                if cellCol < unknowns { cellCol += 1 } else if cellRow < equations - 1 { cellRow += 1; cellCol = 0 } else { solveSimul() }
            case .clear: cells[cellRow][cellCol].chars = []
            default: _ = cells[cellRow][cellCol].apply(action)
            }
        case .simulResult:
            if AppUI.fkey(key) == 1 { mode = .main } else if AppUI.fkey(key) == 2 || action == .clear { mode = .simulEntry }
        }
    }

    private func selectMain() {
        switch menuRow {
        case 0: mode = .polyOrder
        case 1: mode = .simulDims; dimRow = 0
        case 2: mode = .about
        default: wantsExit = true
        }
    }

    private func startCoefs() {
        if coefs.count != order + 1 { coefs = (0...order).map { _ in AppField() } }
        coefRow = 0
        mode = .polyCoefs
    }

    private func solvePoly() {
        let values = coefs.map { $0.number(store) ?? 0 }
        roots = Cx.roots(values)
        mode = .polyRoots
    }

    private func startCells() {
        if cells.count != equations || (cells.first?.count ?? 0) != unknowns + 1 {
            cells = (0..<equations).map { _ in (0...unknowns).map { _ in AppField() } }
        }
        cellRow = 0; cellCol = 0
        mode = .simulEntry
    }

    private func solveSimul() {
        let m = cells.map { $0.map { $0.number(store) ?? 0 } }
        let r = Matrix.rref(m)
        rrefResult = r
        // Unique solution when the left block is the identity.
        var unique = equations >= unknowns
        if unique {
            for i in 0..<unknowns { for j in 0..<unknowns where abs(r[i][j] - (i == j ? 1 : 0)) > 1e-9 { unique = false } }
            for i in unknowns..<equations where abs(r[i][unknowns]) > 1e-9 { unique = false }
        }
        solution = unique ? (0..<unknowns).map { r[$0][unknowns] } : nil
        mode = .simulResult
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        let sub = Tokenizer.subscripts
        switch mode {
        case .main:
            AppUI.menu(&ctx, title: "PlySmlt2 MAIN MENU", items: ["POLY ROOT FINDER", "SIMULT EQN SOLVER", "ABOUT", "QUIT"], selected: menuRow)
            AppUI.softkeys(&ctx, ["", "", "", "", ""], size: size)
        case .about:
            AppUI.centered(&ctx, "PlySmlt2 v2.0", row: 1, inverted: true)
            AppUI.text(&ctx, "Polynomial Root Finder", row: 3, col: 2)
            AppUI.text(&ctx, "and Simultaneous", row: 4, col: 2)
            AppUI.text(&ctx, "Equation Solver", row: 5, col: 2)
            AppUI.text(&ctx, "Reimplemented for Eighty4", row: 7, col: 0)
            AppUI.softkeys(&ctx, ["MAIN", "", "", "", ""], size: size)
        case .polyOrder:
            AppUI.text(&ctx, "POLY ROOT FINDER MODE", row: 0, col: 0, inverted: true)
            AppUI.text(&ctx, "ORDER", row: 2, col: 1)
            for i in 1...10 {
                let label = i == 10 ? "0" : "\(i)"
                AppUI.text(&ctx, label, row: 3 + (i - 1) / 5, col: 1 + ((i - 1) % 5) * 3, inverted: i == order)
            }
            AppUI.text(&ctx, "Pick with ◄ ► or a digit", row: 6, col: 1)
            AppUI.softkeys(&ctx, ["MAIN", "", "", "", "NEXT"], size: size)
        case .polyCoefs:
            AppUI.text(&ctx, "a\(sub[min(9, order)])x^\(order)+…+a\(sub[1])x+a\(sub[0])=0", row: 0, col: 0, inverted: true)
            let visible = 7
            let start = max(0, min(coefRow - (visible - 1), coefs.count - visible))
            for i in 0..<min(visible, coefs.count - start) {
                let idx = start + i
                let p = order - idx
                let label = "a\(sub[p % 10])="
                AppUI.text(&ctx, label, row: 1 + i, col: 1)
                AppUI.text(&ctx, coefs[idx].text, row: 1 + i, col: 4, inverted: idx == coefRow)
                if idx == coefRow { AppUI.text(&ctx, "_", row: 1 + i, col: 4 + coefs[idx].chars.count) }
            }
            AppUI.softkeys(&ctx, ["MAIN", "ORDER", "", "", "SOLVE"], size: size)
        case .polyRoots:
            AppUI.text(&ctx, "ROOTS", row: 0, col: 0, inverted: true)
            if roots.isEmpty { AppUI.text(&ctx, "No roots (a=0)", row: 2, col: 1) }
            for (i, r) in roots.prefix(8).enumerated() {
                AppUI.text(&ctx, "x\(sub[(i + 1) % 10])=\(r.text)", row: 1 + i, col: 1)
            }
            AppUI.softkeys(&ctx, ["MAIN", "COEFS", "", "", ""], size: size)
        case .simulDims:
            AppUI.text(&ctx, "SIMULT EQN SOLVER MODE", row: 0, col: 0, inverted: true)
            AppUI.text(&ctx, "EQUATIONS", row: 2, col: 1, inverted: dimRow == 0)
            AppUI.text(&ctx, "\(equations)", row: 2, col: 12)
            AppUI.text(&ctx, "UNKNOWNS", row: 4, col: 1, inverted: dimRow == 1)
            AppUI.text(&ctx, "\(unknowns)", row: 4, col: 12)
            AppUI.text(&ctx, "◄ ► change, ENTER next", row: 6, col: 1)
            AppUI.softkeys(&ctx, ["MAIN", "", "", "", "NEXT"], size: size)
        case .simulEntry:
            AppUI.text(&ctx, "SYSTEM MATRIX \(equations)×\(unknowns + 1)", row: 0, col: 0, inverted: true)
            let width = 6
            let visCols = 4, visRows = 7
            let c0 = max(0, min(cellCol - (visCols - 1), unknowns + 1 - visCols))
            let r0 = max(0, min(cellRow - (visRows - 1), equations - visRows))
            for c in 0..<min(visCols, unknowns + 1 - c0) {
                let ci = c0 + c
                AppUI.text(&ctx, ci == unknowns ? "  =" : " x\(sub[(ci + 1) % 10])", row: 1, col: 1 + c * width)
            }
            for r in 0..<min(visRows, equations - r0) {
                let ri = r0 + r
                for c in 0..<min(visCols, unknowns + 1 - c0) {
                    let ci = c0 + c
                    let t = cells[ri][ci].text
                    let shown = String(t.suffix(width - 1)).padding(toLength: width - 1, withPad: " ", startingAt: 0)
                    AppUI.text(&ctx, shown, row: 2 + r, col: 1 + c * width, inverted: ri == cellRow && ci == cellCol)
                }
            }
            AppUI.softkeys(&ctx, ["MAIN", "DIMS", "", "", "SOLVE"], size: size)
        case .simulResult:
            if let s = solution {
                AppUI.text(&ctx, "SOLUTION", row: 0, col: 0, inverted: true)
                for (i, v) in s.prefix(8).enumerated() { AppUI.text(&ctx, "x\(sub[(i + 1) % 10])=\(AppUI.short(v))", row: 1 + i, col: 1) }
            } else {
                AppUI.text(&ctx, "NO UNIQUE SOLUTION", row: 0, col: 0, inverted: true)
                AppUI.text(&ctx, "rref:", row: 1, col: 0)
                for (i, row) in rrefResult.prefix(6).enumerated() {
                    AppUI.text(&ctx, row.map { AppUI.short($0, 3) }.joined(separator: " "), row: 2 + i, col: 1)
                }
            }
            AppUI.softkeys(&ctx, ["MAIN", "MATRIX", "", "", ""], size: size)
        }
    }
}
