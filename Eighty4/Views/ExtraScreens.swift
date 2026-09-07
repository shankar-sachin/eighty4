import SwiftUI

/// MATH Solver: equation entry, then the variable list with SOLVE on alpha+ENTER.
struct SolverView: View {
    @Environment(CalculatorState.self) private var state

    var body: some View {
        let store = state.store
        if state.solverStage == 0 {
            ZStack(alignment: .topLeading) {
                Cells(row: 0, col: 0, text: "EQUATION SOLVER")
                Cells(row: 1, col: 0, text: "eqn:0=")
                let width = LCD.cols - 6
                let windowStart = max(0, state.cursor - width + 1)
                let shown = String(state.entry.dropFirst(windowStart).prefix(width))
                Cells(row: 1, col: 6, text: shown)
                BlinkingCursor(row: 1, col: 6 + state.cursor - windowStart, glyph: state.cursorGlyph, underline: state.insertMode)
            }
        } else {
            let vars = state.solverVariables
            let visible = LCD.rows - 1
            let rows = vars.count + 2
            let start = max(0, min(state.solverRow - (visible - 2), max(0, rows - visible)))
            ZStack(alignment: .topLeading) {
                Cells(row: 0, col: 0, text: String((store.solverEqn + "=0").prefix(LCD.cols)))
                ForEach(0..<min(visible, rows - start), id: \.self) { i in
                    let idx = start + i
                    let row = i + 1
                    if idx < vars.count {
                        let name = vars[idx]
                        let typing = state.editorTyping && state.solverRow == idx
                        let value = typing ? String(state.editorBuffer) : ResultFormatter.number(store.reals[name] ?? 0, notation: store.notation, fixed: store.fixedDigits)
                        let text = (state.solverSolved == name ? "■" : " ") + name + "=" + value
                        Cells(row: row, col: 0, text: String(text.prefix(LCD.cols)))
                        if state.solverRow == idx {
                            BlinkingCursor(row: row, col: min(LCD.cols - 1, text.count), glyph: state.cursorGlyph)
                        }
                    } else if idx == vars.count {
                        Cells(row: row, col: 0, text: " bound={⁻1ᴇ99,1ᴇ99}", inverted: state.solverRow == idx)
                    } else {
                        let residual: String = {
                            guard let v = try? Evaluator.number(store.solverEqn, ctx: EvalContext(store: store)) else { return "" }
                            return ResultFormatter.number((v * 1e9).rounded() / 1e9)
                        }()
                        Cells(row: row, col: 0, text: String((" left−rt=" + residual).prefix(LCD.cols)))
                    }
                }
            }
        }
    }
}

/// MEM variable lists (Archive / UnArchive / Mem Management).
struct VarListView: View {
    @Environment(CalculatorState.self) private var state
    let mode: VarListMode

    var body: some View {
        let store = state.store
        let items = state.varListItems(mode)
        let visible = LCD.rows - 2
        let start = max(0, min(state.varListRow - (visible - 1), max(0, items.count - visible)))
        ZStack(alignment: .topLeading) {
            Cells(row: 0, col: 0, text: "RAM FREE" + String(repeating: " ", count: 6) + String(format: "%6d", MemoryModel.ramFree(store)))
            Cells(row: 1, col: 0, text: "ARC FREE" + String(repeating: " ", count: 6) + String(format: "%6@", MemoryModel.arcFreeText(store)))
            if items.isEmpty {
                Cells(row: 3, col: 2, text: mode == .unarchive ? "No archived variables" : "No variables")
            }
            ForEach(0..<min(visible, max(0, items.count - start)), id: \.self) { i in
                let idx = start + i
                let item = items[idx]
                let marker = store.archived.contains(item.name) ? "*" : " "
                let size = String(format: "%5d", item.bytes)
                let line = marker + item.name.padding(toLength: 14, withPad: " ", startingAt: 0) + size
                Cells(row: i + 2, col: 0, text: idx == state.varListRow ? "▶" : " ")
                Cells(row: i + 2, col: 1, text: String(line.prefix(LCD.cols - 1)), inverted: idx == state.varListRow)
            }
            if start + visible < items.count { Cells(row: LCD.rows - 1, col: LCD.cols - 1, text: "↓") }
        }
    }
}

/// "1:No 2:Yes" confirmation screens.
struct ConfirmView: View {
    let kind: ConfirmKind

    var body: some View {
        TextScreenView(lines: kind.lines)
    }
}

/// PRGM editor: "PROGRAM:NAME" then ":"-prefixed lines, current line editable.
struct ProgramEditorView: View {
    @Environment(CalculatorState.self) private var state

    var body: some View {
        let visible = LCD.rows - 1
        let lines = state.programLines
        let start = max(0, min(state.programRow - (visible - 1), max(0, lines.count - visible)))
        ZStack(alignment: .topLeading) {
            Cells(row: 0, col: 0, text: String(("PROGRAM:" + state.programName).prefix(LCD.cols)))
            ForEach(0..<min(visible, max(0, lines.count - start)), id: \.self) { i in
                let idx = start + i
                let row = i + 1
                Cells(row: row, col: 0, text: ":")
                if idx == state.programRow {
                    let width = LCD.cols - 1
                    let windowStart = max(0, state.cursor - width + 1)
                    let shown = String(state.entry.dropFirst(windowStart).prefix(width))
                    Cells(row: row, col: 1, text: shown)
                    BlinkingCursor(row: row, col: 1 + state.cursor - windowStart, glyph: state.cursorGlyph, underline: state.insertMode)
                } else {
                    Cells(row: row, col: 1, text: String(lines[idx].prefix(LCD.cols - 1)))
                }
            }
        }
    }
}

/// NEW program / group name prompt.
struct NameEntryView: View {
    @Environment(CalculatorState.self) private var state
    let title: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            Cells(row: 0, col: 0, text: title)
            Cells(row: 1, col: 0, text: "Name=" + String(state.nameBuffer))
            BlinkingCursor(row: 1, col: 5 + state.nameBuffer.count, glyph: state.cursorGlyph)
        }
    }
}

/// Menu( from a running program.
struct ProgramMenuView: View {
    @Environment(CalculatorState.self) private var state
    let title: String
    let items: [String]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Cells(row: 0, col: 0, text: String(title.prefix(LCD.cols)), inverted: true)
            ForEach(Array(items.prefix(9).enumerated()), id: \.offset) { i, item in
                Cells(row: i + 1, col: 0, text: "\(i + 1)", inverted: i == state.programMenuRow)
                Cells(row: i + 1, col: 1, text: ":" + String(item.prefix(LCD.cols - 2)))
            }
        }
    }
}
