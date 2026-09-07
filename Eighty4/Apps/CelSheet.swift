import SwiftUI

/// CelSheet: a small spreadsheet. Cells hold numbers, text, or formulas referencing other cells (A1, B2:B5).
final class CelSheetApp: Game {
    let title = "CELSHEET"
    private(set) var wantsExit = false
    let handlesClear = true

    static let columns = Array("ABCDEFGHIJ").map(String.init)
    static let rows = 99
    private let visibleCols = 4, visibleRows = 7, cellWidth = 6

    private var row = 0, col = 0
    private var field = AppField()
    private var typing = false
    private let store: VariableStore

    init(store: VariableStore) { self.store = store }

    func update(now: TimeInterval) {}
    func press(_ key: KeyID) {}

    private var name: String { Self.columns[col] + "\(row + 1)" }

    private func commit() {
        guard typing else { return }
        typing = false
        if field.chars.isEmpty { store.sheet.removeValue(forKey: name) } else { store.sheet[name] = field.text }
        field.chars = []
    }

    func handle(_ key: KeyID, _ action: KeyAction) {
        switch action {
        case .up: commit(); row = max(0, row - 1)
        case .down: commit(); row = min(Self.rows - 1, row + 1)
        case .left: commit(); col = max(0, col - 1)
        case .right: commit(); col = min(Self.columns.count - 1, col + 1)
        case .enter: commit(); row = min(Self.rows - 1, row + 1)
        case .del:
            if typing { _ = field.apply(action) } else { store.sheet.removeValue(forKey: name) }
        case .clear:
            if typing { typing = false; field.chars = [] } else { wantsExit = true }
        case .insert:
            if !typing { typing = true; field.chars = [] }
            _ = field.apply(action)
        default: break
        }
    }

    // MARK: - Evaluation

    /// Value of a cell, resolving formulas with cell references and ranges.
    func value(_ cell: String, depth: Int = 0) -> Value? {
        guard depth < 20, let raw = store.sheet[cell], !raw.isEmpty else { return nil }
        if let d = Double(raw.replacingOccurrences(of: "⁻", with: "-")) { return .num(d) }
        var text = raw
        // Ranges like A1:A5 → {values}
        let rangePattern = try! NSRegularExpression(pattern: "([A-J])([0-9]{1,2}):([A-J])([0-9]{1,2})")
        for m in rangePattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            let c1 = Self.columns.firstIndex(of: String(text[Range(m.range(at: 1), in: text)!]))!
            let r1 = Int(text[Range(m.range(at: 2), in: text)!])!
            let c2 = Self.columns.firstIndex(of: String(text[Range(m.range(at: 3), in: text)!]))!
            let r2 = Int(text[Range(m.range(at: 4), in: text)!])!
            var vals: [String] = []
            for c in min(c1, c2)...max(c1, c2) { for r in min(r1, r2)...max(r1, r2) {
                if let v = value(Self.columns[c] + "\(r)", depth: depth + 1)?.asDouble { vals.append(ResultFormatter.number(v)) }
            } }
            text.replaceSubrange(Range(m.range, in: text)!, with: "{" + vals.joined(separator: ",") + "}")
        }
        let refPattern = try! NSRegularExpression(pattern: "([A-J])([0-9]{1,2})")
        for m in refPattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            let ref = String(text[Range(m.range, in: text)!])
            let v = value(ref, depth: depth + 1)?.asDouble ?? 0
            text.replaceSubrange(Range(m.range, in: text)!, with: "(" + ResultFormatter.number(v) + ")")
        }
        if let v = try? Evaluator.evaluate(text, ctx: EvalContext(store: store)) { return v }
        return .str(raw)
    }

    private func display(_ cell: String) -> String {
        guard let v = value(cell) else { return "" }
        switch v {
        case .str(let s): return s
        default: return ResultFormatter.format(v, store: store)
        }
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        let c0 = max(0, min(col - (visibleCols - 1), Self.columns.count - visibleCols))
        let r0 = max(0, min(row - (visibleRows - 1), Self.rows - visibleRows))
        AppUI.text(&ctx, "  ", row: 0, col: 0, inverted: true)
        for c in 0..<visibleCols {
            let ci = c0 + c
            let label = Self.columns[ci].padding(toLength: cellWidth, withPad: " ", startingAt: 0)
            AppUI.text(&ctx, label, row: 0, col: 2 + c * cellWidth, inverted: ci != col)
        }
        for r in 0..<visibleRows {
            let ri = r0 + r
            AppUI.text(&ctx, String(format: "%2d", ri + 1), row: 1 + r, col: 0, inverted: ri != row)
            for c in 0..<visibleCols {
                let ci = c0 + c
                let cell = Self.columns[ci] + "\(ri + 1)"
                let text = String(display(cell).prefix(cellWidth - 1)).padding(toLength: cellWidth - 1, withPad: " ", startingAt: 0)
                AppUI.text(&ctx, text, row: 1 + r, col: 2 + c * cellWidth, inverted: ri == row && ci == col)
            }
        }
        let edit = typing ? field.text : (store.sheet[name] ?? "")
        AppUI.text(&ctx, name + ":", row: 9, col: 0)
        AppUI.text(&ctx, String(edit.suffix(21)) + (typing ? "_" : ""), row: 9, col: 4)
    }
}
