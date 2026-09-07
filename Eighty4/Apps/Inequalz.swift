import SwiftUI

/// Inequalz: Y= with inequality relations, graphed as shaded regions.
final class InequalzApp: Game {
    let title = "INEQUALZ"
    private(set) var wantsExit = false
    let handlesClear = true

    private enum Mode { case editor, graph }
    private var mode: Mode = .editor
    private var row = 0
    private var field = AppField()
    private let store: VariableStore
    private let keys = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]
    static let relations = ["=", "<", "≤", ">", "≥"]

    init(store: VariableStore) {
        self.store = store
        field.text = store.yFuncs[1] ?? ""
    }

    func update(now: TimeInterval) {}
    func press(_ key: KeyID) {}

    private func relation(_ n: Int) -> Int { store.options["ineq\(n)", default: 0] }

    private func commit() {
        let n = keys[row]
        store.yFuncs[n] = field.text.isEmpty ? nil : field.text
    }

    func handle(_ key: KeyID, _ action: KeyAction) {
        switch mode {
        case .editor:
            if let f = AppUI.fkey(key) { store.options["ineq\(keys[row])"] = f - 1; return }
            switch action {
            case .up: commit(); row = (row + 9) % 10; field.text = store.yFuncs[keys[row]] ?? ""
            case .down, .enter: commit(); row = (row + 1) % 10; field.text = store.yFuncs[keys[row]] ?? ""
            case .openGraph: commit(); mode = .graph
            case .clear: if field.chars.isEmpty { commit(); wantsExit = true } else { field.chars = [] }
            case .openYEquals: break
            default: _ = field.apply(action)
            }
        case .graph:
            switch action {
            case .clear, .openYEquals: mode = .editor
            case .openGraph: break
            default: break
            }
        }
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        let sub = Tokenizer.subscripts
        switch mode {
        case .editor:
            AppUI.text(&ctx, "INEQUALZ  F1-F5: = < ≤ > ≥", row: 0, col: 0, inverted: true)
            let visible = 8
            let start = max(0, min(row - (visible - 1), 10 - visible))
            for i in 0..<visible {
                let idx = start + i
                let n = keys[idx]
                let label = "Y\(sub[n])" + Self.relations[relation(n)]
                AppUI.text(&ctx, label, row: 1 + i, col: 0)
                let text = idx == row ? field.text : (store.yFuncs[n] ?? "")
                AppUI.text(&ctx, String(text.suffix(22)), row: 1 + i, col: 3, inverted: idx == row)
                if idx == row { AppUI.text(&ctx, "_", row: 1 + i, col: 3 + min(22, text.count)) }
            }
            AppUI.softkeys(&ctx, ["=", "<", "≤", ">", "≥"], size: size)
        case .graph:
            let w = GraphWindow(store: store)
            guard w.isValid else { return }
            GraphRenderer.drawGrid(&ctx, size, w, store)
            for n in keys where !(store.yFuncs[n] ?? "").isEmpty {
                let rel = relation(n)
                let color = GraphRenderer.color(n)
                var fill = Path()
                var line = Path()
                var pen = false
                for col in 0..<Int(size.width) {
                    let x = w.xAt(column: col, size)
                    guard let y = Graphing.y(n, at: x, store: store) else { pen = false; continue }
                    let py = w.py(y, size)
                    guard abs(py) < 5000 else { pen = false; continue }
                    let pt = CGPoint(x: CGFloat(col), y: py)
                    if rel == 0 || rel == 2 || rel == 4 || col % 6 < 3 {
                        if pen { line.addLine(to: pt) } else { line.move(to: pt); pen = true }
                    } else { pen = false }
                    switch rel {
                    case 1, 2: fill.addRect(CGRect(x: CGFloat(col), y: py, width: 1, height: max(0, size.height - py)))
                    case 3, 4: fill.addRect(CGRect(x: CGFloat(col), y: 0, width: 1, height: max(0, py)))
                    default: break
                    }
                }
                ctx.fill(fill, with: .color(color.opacity(0.25)))
                ctx.stroke(line, with: .color(color), lineWidth: 1.5)
            }
            ctx.fill(Path(CGRect(x: 0, y: size.height - 14, width: size.width, height: 14)), with: .color(.white.opacity(0.85)))
            ctx.drawText("CLEAR: back to Y=", at: CGPoint(x: 2, y: size.height - 13), size: 10, weight: .regular, color: .black)
        }
    }
}
