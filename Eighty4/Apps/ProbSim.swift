import SwiftUI

/// Prob Sim: coin, dice, marble, spinner, card and random-number simulations with a frequency chart.
final class ProbSimApp: Game {
    let title = "PROB SIM"
    private(set) var wantsExit = false
    let handlesClear = true

    private struct Sim {
        let title: String
        let outcomes: [String]
        let sample: () -> Int
    }

    private var menuRow = 0
    private var sim: Sim? = nil
    private var counts: [Int] = []
    private var last: String = ""
    private var total = 0

    private static let sims: [Sim] = [
        Sim(title: "TOSS COINS (2)", outcomes: ["0H", "1H", "2H"]) { Int.random(in: 0...1) + Int.random(in: 0...1) },
        Sim(title: "ROLL DICE (2)", outcomes: (2...12).map(String.init)) { Int.random(in: 1...6) + Int.random(in: 1...6) - 2 },
        Sim(title: "PICK MARBLES", outcomes: ["RED", "BLU", "GRN", "YEL"]) { [0, 0, 0, 1, 1, 2, 3][Int.random(in: 0..<7)] },
        Sim(title: "SPIN SPINNER", outcomes: ["1", "2", "3", "4"]) { Int.random(in: 0...3) },
        Sim(title: "DRAW CARDS", outcomes: ["♠", "♥", "♦", "♣"]) { Int.random(in: 0...3) },
        Sim(title: "RANDOM NUMBERS", outcomes: (1...10).map(String.init)) { Int.random(in: 0...9) },
    ]

    func update(now: TimeInterval) {}
    func press(_ key: KeyID) {}

    private func start(_ i: Int) {
        sim = Self.sims[i]
        counts = Array(repeating: 0, count: Self.sims[i].outcomes.count)
        total = 0
        last = ""
    }

    private func trial(_ n: Int) {
        guard let s = sim else { return }
        for _ in 0..<n {
            let r = s.sample()
            counts[r] += 1
            total += 1
            last = s.outcomes[r]
            if s.title == "DRAW CARDS" { last = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"][Int.random(in: 0..<13)] + s.outcomes[r] }
        }
    }

    func handle(_ key: KeyID, _ action: KeyAction) {
        if sim == nil {
            if let d = AppUI.digit(action), d >= 1, d <= Self.sims.count { start(d - 1); return }
            switch action {
            case .up: menuRow = (menuRow + Self.sims.count - 1) % Self.sims.count
            case .down: menuRow = (menuRow + 1) % Self.sims.count
            case .enter: start(menuRow)
            case .clear: wantsExit = true
            default: break
            }
            return
        }
        switch AppUI.fkey(key) {
        case 1: trial(1)
        case 2: trial(10)
        case 3: trial(50)
        case 4: counts = counts.map { _ in 0 }; total = 0; last = ""
        case 5: sim = nil
        default:
            if action == .enter { trial(1) }
            if action == .clear { sim = nil }
        }
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        guard let s = sim else {
            AppUI.menu(&ctx, title: "PROBABILITY SIMULATION", items: Self.sims.map { $0.title }, selected: menuRow)
            AppUI.text(&ctx, "CLEAR quits", row: 8, col: 0)
            return
        }
        AppUI.text(&ctx, s.title, row: 0, col: 0, inverted: true)
        AppUI.text(&ctx, "n=\(total)", row: 0, col: 18)
        AppUI.text(&ctx, "Last: \(last)", row: 1, col: 0)
        // Bar chart
        let chartTop: CGFloat = 46, chartBottom = size.height - 38
        let n = CGFloat(s.outcomes.count)
        let slot = (size.width - 20) / n
        let maxCount = max(1, counts.max() ?? 1)
        for (i, c) in counts.enumerated() {
            let h = CGFloat(c) / CGFloat(maxCount) * (chartBottom - chartTop)
            let x = 10 + CGFloat(i) * slot + slot * 0.15
            ctx.fill(Path(CGRect(x: x, y: chartBottom - h, width: slot * 0.7, height: h)), with: .color(GraphRenderer.color(1)))
            ctx.drawText(s.outcomes[i], at: CGPoint(x: x + slot * 0.35, y: chartBottom + 3), size: 9, weight: .regular, color: .black, anchor: .top)
            if c > 0 { ctx.drawText("\(c)", at: CGPoint(x: x + slot * 0.35, y: chartBottom - h - 2), size: 8, weight: .regular, color: .black, anchor: .bottom) }
        }
        var axis = Path()
        axis.move(to: CGPoint(x: 8, y: chartBottom)); axis.addLine(to: CGPoint(x: size.width - 8, y: chartBottom))
        ctx.stroke(axis, with: .color(.black), lineWidth: 1)
        AppUI.softkeys(&ctx, ["+1", "+10", "+50", "CLEAR", "MENU"], size: size)
    }
}
