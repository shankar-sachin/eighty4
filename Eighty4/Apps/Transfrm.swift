import SwiftUI

/// Transfrm: graph Y1 with live parameters A, B, C, D adjusted from the graph screen.
final class TransfrmApp: Game {
    let title = "TRANSFRM"
    private(set) var wantsExit = false
    let handlesClear = true

    private enum Mode { case graph, editY, settings }
    private var mode: Mode = .graph
    private var param = 0
    private let names = ["A", "B", "C", "D"]
    private static let steps = [0.1, 0.5, 1, 2, 5]
    private var stepIndex = 2
    private var field = AppField()
    private var typed = AppField()
    private let store: VariableStore

    init(store: VariableStore) {
        self.store = store
        field.text = store.yFuncs[1] ?? "AX²+BX+C"
        if store.yFuncs[1] == nil { store.yFuncs[1] = field.text }
        for n in names where store.reals[n] == nil { store.reals[n] = 1 }
    }

    func update(now: TimeInterval) {}
    func press(_ key: KeyID) {}

    private var step: Double { Self.steps[stepIndex] }

    func handle(_ key: KeyID, _ action: KeyAction) {
        switch mode {
        case .graph:
            if AppUI.fkey(key) == 1 { mode = .editY; return }
            if AppUI.fkey(key) == 2 { mode = .settings; return }
            switch action {
            case .up: param = (param + 3) % 4; typed.chars = []
            case .down: param = (param + 1) % 4; typed.chars = []
            case .left: store.reals[names[param]] = (store.reals[names[param]] ?? 0) - step; typed.chars = []
            case .right: store.reals[names[param]] = (store.reals[names[param]] ?? 0) + step; typed.chars = []
            case .enter:
                if let v = typed.number(store) { store.reals[names[param]] = v }
                typed.chars = []
            case .clear: if typed.chars.isEmpty { wantsExit = true } else { typed.chars = [] }
            default: _ = typed.apply(action)
            }
        case .editY:
            switch action {
            case .enter, .openGraph:
                store.yFuncs[1] = field.text.isEmpty ? nil : field.text
                mode = .graph
            case .clear: if field.chars.isEmpty { mode = .graph } else { field.chars = [] }
            default: _ = field.apply(action)
            }
        case .settings:
            switch action {
            case .left: stepIndex = max(0, stepIndex - 1)
            case .right: stepIndex = min(Self.steps.count - 1, stepIndex + 1)
            case .enter, .clear, .openGraph: mode = .graph
            default: break
            }
        }
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        switch mode {
        case .editY:
            AppUI.text(&ctx, "TRANSFRM  Y1 uses A B C D", row: 0, col: 0, inverted: true)
            AppUI.text(&ctx, "Y₁=", row: 2, col: 0)
            AppUI.text(&ctx, String(field.text.suffix(22)) + "_", row: 2, col: 3)
            AppUI.text(&ctx, "ENTER to graph", row: 4, col: 0)
        case .settings:
            AppUI.text(&ctx, "TRANSFRM SETTINGS", row: 0, col: 0, inverted: true)
            AppUI.text(&ctx, "Step: ◄ \(AppUI.number(step)) ►", row: 2, col: 1)
            AppUI.text(&ctx, "ENTER to return", row: 4, col: 1)
        case .graph:
            let w = GraphWindow(store: store)
            guard w.isValid else { return }
            GraphRenderer.drawGrid(&ctx, size, w, store)
            let samples = Graphing.samples(store)
            GraphRenderer.drawSamples(&ctx, size, store, samples)
            ctx.fill(Path(CGRect(x: 0, y: 0, width: 96, height: 92)), with: .color(.white.opacity(0.85)))
            ctx.drawText("Y₁=" + String((store.yFuncs[1] ?? "").prefix(11)), at: CGPoint(x: 2, y: 1), size: 10, weight: .regular, color: GraphRenderer.color(1))
            for (i, n) in names.enumerated() {
                let v = store.reals[n] ?? 0
                let text = (i == param && !typed.chars.isEmpty) ? "\(n)=\(typed.text)_" : "\(n)=\(AppUI.short(v, 4))"
                ctx.drawText((i == param ? "▶" : " ") + text, at: CGPoint(x: 2, y: 15 + CGFloat(i) * 14), size: 11, weight: i == param ? .bold : .regular, color: .black)
            }
            ctx.drawText("Step=\(AppUI.number(step))", at: CGPoint(x: 2, y: 73), size: 10, weight: .regular, color: .black)
            AppUI.softkeys(&ctx, ["Y=", "SETUP", "", "", ""], size: size)
        }
    }
}
