import SwiftUI

/// Inequalz: Y= with inequality relations, graphed as shaded regions.
final class InequalzApp: Game {
    let title = "INEQUALZ"
    private(set) var wantsExit = false
    let handlesClear = true

    private enum Mode { case editor, graph }
    private var mode: Mode = .editor
    private var row = 0
    /// Cursor sits on the relation symbol (◀ from the expression); F1–F5 pick = < ≤ > ≥ there.
    private var onRelation = false
    private var field = AppField()
    private let store: VariableStore
    /// Rows: Y₁…Y₀ (1…9, 0) then the X= relations X₁…X₆ (11…16), which are functions of Y.
    private let keys = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 11, 12, 13, 14, 15, 16]
    static let relations = ["=", "<", "≤", ">", "≥"]

    init(store: VariableStore) {
        self.store = store
        field.text = store.yFuncs[1] ?? ""
    }

    func update(now: TimeInterval) {}
    func press(_ key: KeyID) {}

    private func isX(_ n: Int) -> Bool { n > 10 }
    private func relation(_ n: Int) -> Int { store.options["ineq\(n)", default: 0] }
    private func label(_ n: Int) -> String {
        let sub = Tokenizer.subscripts
        return isX(n) ? "X\(sub[n - 10])" : "Y\(sub[n])"
    }
    private func text(_ n: Int) -> String { isX(n) ? (store.funcs["X\(n - 10)"] ?? "") : (store.yFuncs[n] ?? "") }
    private func setText(_ n: Int, _ t: String) {
        if isX(n) { store.funcs["X\(n - 10)"] = t.isEmpty ? nil : t } else { store.yFuncs[n] = t.isEmpty ? nil : t }
    }

    private func commit() { setText(keys[row], field.text) }

    private func move(_ delta: Int) {
        commit()
        row = (row + delta + keys.count) % keys.count
        field.text = text(keys[row])
    }

    func handle(_ key: KeyID, _ action: KeyAction) {
        switch mode {
        case .editor:
            if onRelation {
                if let f = AppUI.fkey(key) { store.options["ineq\(keys[row])"] = f - 1; onRelation = false; return }
                switch action {
                case .right, .enter, .clear: onRelation = false
                case .up: move(-1)
                case .down: move(1)
                case .openGraph: commit(); onRelation = false; mode = .graph
                default: break
                }
                return
            }
            if case .openGraph = action { commit(); mode = .graph; return }
            if let f = AppUI.fkey(key), f < 5 { store.options["ineq\(keys[row])"] = f - 1; return }   // F1–F4 shortcuts; ≥ needs the symbol cursor
            switch action {
            case .up: move(-1)
            case .down, .enter: move(1)
            case .left: onRelation = true
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
        switch mode {
        case .editor:
            AppUI.text(&ctx, "INEQUALZ ◀ symbol F1-F5:=<≤>≥", row: 0, col: 0, inverted: true)
            let visible = 8
            let start = max(0, min(row - (visible - 1), keys.count - visible))
            for i in 0..<visible {
                let idx = start + i
                let n = keys[idx]
                AppUI.text(&ctx, label(n), row: 1 + i, col: 0)
                AppUI.text(&ctx, Self.relations[relation(n)], row: 1 + i, col: 2, inverted: idx == row && onRelation)
                let text = idx == row ? field.text : self.text(n)
                AppUI.text(&ctx, String(text.suffix(22)), row: 1 + i, col: 3, inverted: idx == row && !onRelation)
                if idx == row, !onRelation { AppUI.text(&ctx, "_", row: 1 + i, col: 3 + min(22, text.count)) }
            }
            AppUI.softkeys(&ctx, ["=", "<", "≤", ">", "≥"], size: size)
        case .graph:
            let w = GraphWindow(store: store)
            guard w.isValid else { return }
            GraphRenderer.drawGrid(&ctx, size, w, store)
            // X= relations: x = f(Y), shaded to the left (<, ≤) or right (>, ≥) of the curve.
            for n in keys where isX(n) && !text(n).isEmpty {
                let rel = relation(n)
                let color = GraphRenderer.color(n - 10)
                let expr = text(n)
                var fill = Path()
                var line = Path()
                var pen = false
                for r in 0..<Int(size.height) {
                    store.overrides["Y"] = w.yAt(row: Double(r), size)
                    guard let x = try? Evaluator.number(expr, ctx: EvalContext(store: store)) else { pen = false; continue }
                    let px = w.px(x, size)
                    guard abs(px) < 5000 else { pen = false; continue }
                    let pt = CGPoint(x: px, y: CGFloat(r))
                    if rel == 0 || rel == 2 || rel == 4 || r % 6 < 3 {
                        if pen { line.addLine(to: pt) } else { line.move(to: pt); pen = true }
                    } else { pen = false }
                    switch rel {
                    case 1, 2: fill.addRect(CGRect(x: 0, y: CGFloat(r), width: max(0, px), height: 1))
                    case 3, 4: fill.addRect(CGRect(x: px, y: CGFloat(r), width: max(0, size.width - px), height: 1))
                    default: break
                    }
                }
                store.overrides["Y"] = nil
                ctx.fill(fill, with: .color(color.opacity(0.25)))
                ctx.stroke(line, with: .color(color), lineWidth: 1.5)
            }
            for n in keys where !isX(n) && !(store.yFuncs[n] ?? "").isEmpty {
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
