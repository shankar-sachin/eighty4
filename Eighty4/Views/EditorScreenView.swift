import SwiftUI

/// MODE / FORMAT / TBLSET / WINDOW / STAT PLOT / TVM editors.
struct SettingsEditorView: View {
    @Environment(CalculatorState.self) private var state
    let id: EditorID

    var body: some View {
        let def = Editors.def(id)
        let titleRows = def.title == nil ? 0 : 1
        let visible = LCD.rows - titleRows
        let start = max(0, min(state.editorRow - (visible - 1), max(0, def.rows.count - visible)))
        ZStack(alignment: .topLeading) {
            if let t = def.title { Cells(row: 0, col: 0, text: t) }
            ForEach(0..<min(visible, max(0, def.rows.count - start)), id: \.self) { i in
                let idx = start + i
                let row = i + titleRows
                switch def.rows[idx] {
                case .options(let sr):
                    optionsRow(sr, row: row, isCursorRow: idx == state.editorRow)
                case .number(let key, let label):
                    numberRow(key: key, label: label, row: row, isCursorRow: idx == state.editorRow)
                }
            }
        }
    }

    @ViewBuilder
    private func optionsRow(_ sr: SettingRow, row: Int, isCursorRow: Bool) -> some View {
        let selected = state.store.options[sr.key] ?? 0
        let positions: [(Int, String)] = {
            var col = 0
            var out: [(Int, String)] = []
            if let l = sr.label { out.append((0, l)); col = l.count + 1 }
            for o in sr.options { out.append((col, o)); col += o.count + 1 }
            return out
        }()
        let offset = sr.label == nil ? 0 : 1
        ForEach(Array(positions.enumerated()), id: \.offset) { i, p in
            let optionIndex = i - offset
            Cells(row: row, col: p.0, text: p.1,
                  inverted: optionIndex >= 0 && optionIndex == selected,
                  outlined: isCursorRow && optionIndex == state.editorCol)
        }
    }

    @ViewBuilder
    private func numberRow(key: String, label: String, row: Int, isCursorRow: Bool) -> some View {
        let typing = isCursorRow && state.editorTyping
        let value = typing ? String(state.editorBuffer) : ResultFormatter.number(state.store.numbers[key] ?? 0, notation: state.store.notation, fixed: state.store.fixedDigits)
        let prefix = (state.tvmSolved == key ? "■" : " ") + label + "="
        let text = id == .tvm ? prefix + value : label + "=" + value
        Cells(row: row, col: 0, text: String(text.prefix(LCD.cols)))
        if isCursorRow {
            BlinkingCursor(row: row, col: min(LCD.cols - 1, text.count), glyph: state.cursorGlyph)
        }
    }
}

struct YEqualsView: View {
    @Environment(CalculatorState.self) private var state

    var body: some View {
        let sub = Tokenizer.subscripts
        let visible = LCD.rows - 1
        let start = max(0, min(state.yRow - (visible - 1), 10 - visible))
        ZStack(alignment: .topLeading) {
            ForEach(1...3, id: \.self) { i in
                Cells(row: 0, col: (i - 1) * 7, text: "Plot\(i)", inverted: state.store.plotOn(i))
            }
            ForEach(0..<visible, id: \.self) { i in
                let idx = start + i
                let n = idx == 9 ? 0 : idx + 1
                let row = i + 1
                let label = (state.store.isYEnabled(n) ? "\\" : " ") + "Y\(sub[n])="
                Cells(row: row, col: 0, text: label)
                if idx == state.yRow {
                    let chars = state.entry
                    let width = LCD.cols - label.count
                    let windowStart = max(0, state.cursor - width + 1)
                    let shown = String(chars.dropFirst(windowStart).prefix(width))
                    Cells(row: row, col: label.count, text: shown)
                    BlinkingCursor(row: row, col: label.count + state.cursor - windowStart, glyph: state.cursorGlyph, underline: state.insertMode)
                } else {
                    let text = state.store.yFuncs[n] ?? ""
                    Cells(row: row, col: label.count, text: String(text.prefix(LCD.cols - label.count)))
                }
            }
        }
    }
}

struct ListEditorView: View {
    @Environment(CalculatorState.self) private var state

    private let colWidth = 8
    private let visibleCols = 3
    private let visibleRows = 7

    var body: some View {
        let sub = Tokenizer.subscripts
        let firstCol = max(0, min(state.listCol - (visibleCols - 1), 6 - visibleCols))
        let store = state.store
        let currentCount = store.lists["L\(state.listCol + 1)"]?.count ?? 0
        let rowStart = max(0, state.listRow - (visibleRows - 1))
        ZStack(alignment: .topLeading) {
            ForEach(0..<visibleCols, id: \.self) { c in
                let col = firstCol + c
                Cells(row: 0, col: c * colWidth + 1, text: "L\(sub[col + 1])")
            }
            ForEach(0..<visibleRows, id: \.self) { r in
                let rowIndex = rowStart + r
                ForEach(0..<visibleCols, id: \.self) { c in
                    let col = firstCol + c
                    let list = store.lists["L\(col + 1)"] ?? []
                    let isCursor = col == state.listCol && rowIndex == state.listRow
                    let text: String = rowIndex < list.count ? String(ResultFormatter.number(list[rowIndex]).prefix(colWidth - 1)) : (isCursor ? "" : "")
                    let padded = String(repeating: " ", count: max(0, colWidth - 1 - text.count)) + text
                    Cells(row: r + 1, col: c * colWidth, text: padded, inverted: isCursor)
                }
            }
            let bottom: String = {
                let name = "L\(sub[state.listCol + 1])(\(state.listRow + 1))="
                if state.editorTyping { return name + String(state.editorBuffer) }
                let list = store.lists["L\(state.listCol + 1)"] ?? []
                return name + (state.listRow < list.count ? ResultFormatter.number(list[state.listRow]) : "")
            }()
            Cells(row: LCD.rows - 1, col: 0, text: String(bottom.prefix(LCD.cols)))
            BlinkingCursor(row: LCD.rows - 1, col: min(LCD.cols - 1, bottom.count), glyph: state.cursorGlyph)
            if currentCount > visibleRows {
                Cells(row: LCD.rows - 2, col: LCD.cols - 1, text: "↓")
            }
        }
    }
}

struct MatrixEditorView: View {
    @Environment(CalculatorState.self) private var state
    let name: String

    private let cellWidth = 6
    private let visibleCols = 4
    private let visibleRows = 7

    var body: some View {
        let m = state.store.matrices[name] ?? [[0]]
        let (rows, cols) = Matrix.dims(m)
        let rowStart = max(0, state.matRow - (visibleRows - 1))
        let colStart = max(0, state.matCol - (visibleCols - 1))
        ZStack(alignment: .topLeading) {
            Cells(row: 0, col: 0, text: "MATRIX[\(name)]")
            let dimsTyping = state.matRow == -1 && state.editorTyping
            let rText = dimsTyping && state.matCol == 0 ? String(state.editorBuffer) : "\(rows)"
            let cText = dimsTyping && state.matCol == 1 ? String(state.editorBuffer) : "\(cols)"
            Cells(row: 0, col: 12, text: rText, inverted: state.matRow == -1 && state.matCol == 0)
            Cells(row: 0, col: 12 + rText.count, text: " ×")
            Cells(row: 0, col: 15 + rText.count, text: cText, inverted: state.matRow == -1 && state.matCol == 1)
            ForEach(0..<min(visibleRows, rows - rowStart), id: \.self) { r in
                let ri = rowStart + r
                ForEach(0..<min(visibleCols, cols - colStart), id: \.self) { c in
                    let ci = colStart + c
                    let isCursor = ri == state.matRow && ci == state.matCol
                    let v = String(ResultFormatter.number(m[ri][ci]).prefix(cellWidth - 1))
                    let padded = String(repeating: " ", count: max(0, cellWidth - 1 - v.count)) + v
                    Cells(row: r + 1, col: 1 + c * cellWidth, text: padded, inverted: isCursor)
                }
            }
            Cells(row: 1, col: 0, text: "[")
            Cells(row: min(rows, visibleRows), col: 1 + min(visibleCols, cols - colStart) * cellWidth, text: "]")
            let bottom: String = {
                if state.matRow == -1 { return dimsTyping ? "" : "" }
                let label = "\(state.matRow + 1),\(state.matCol + 1)="
                if state.editorTyping { return label + String(state.editorBuffer) }
                return label + ResultFormatter.number(m[min(rows - 1, state.matRow)][min(cols - 1, state.matCol)])
            }()
            Cells(row: LCD.rows - 1, col: 0, text: String(bottom.prefix(LCD.cols)))
            if state.matRow >= 0 {
                BlinkingCursor(row: LCD.rows - 1, col: min(LCD.cols - 1, bottom.count), glyph: state.cursorGlyph)
            }
        }
    }
}
