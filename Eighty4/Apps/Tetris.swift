import SwiftUI

/// Simple Tetris: ←→ move, ↑ rotate, ↓ soft drop, enter hard drop.
final class TetrisGame: Game {
    let title = "TETRIS"

    static let cols = 10
    static let rows = 20

    struct Piece {
        var type: Int
        var rot: Int
        var x: Int
        var y: Int
    }

    /// (box size, cells) for I O T S Z J L
    static let shapes: [(Int, [(Int, Int)])] = [
        (4, [(0, 1), (1, 1), (2, 1), (3, 1)]),
        (2, [(0, 0), (1, 0), (0, 1), (1, 1)]),
        (3, [(0, 1), (1, 1), (2, 1), (1, 0)]),
        (3, [(1, 0), (2, 0), (0, 1), (1, 1)]),
        (3, [(0, 0), (1, 0), (1, 1), (2, 1)]),
        (3, [(0, 0), (0, 1), (1, 1), (2, 1)]),
        (3, [(2, 0), (0, 1), (1, 1), (2, 1)]),
    ]

    static let colors: [Color] = [
        Color(red: 0.2, green: 0.9, blue: 0.95), Color(red: 1, green: 0.85, blue: 0.2), Color(red: 0.7, green: 0.3, blue: 0.9),
        Color(red: 0.3, green: 0.85, blue: 0.3), Color(red: 0.95, green: 0.25, blue: 0.25), Color(red: 0.25, green: 0.4, blue: 0.95),
        Color(red: 1, green: 0.55, blue: 0.15),
    ]

    private(set) var grid = [[Int]](repeating: [Int](repeating: 0, count: cols), count: rows)
    private var current: Piece
    private var next: Int
    private(set) var score = 0
    private(set) var lines = 0
    private(set) var level = 1
    private(set) var over = false
    private var acc = 0.0
    private var last: TimeInterval?

    init() {
        next = Int.random(in: 0..<7)
        current = Piece(type: Int.random(in: 0..<7), rot: 0, x: 3, y: 0)
    }

    private func cells(_ p: Piece) -> [(Int, Int)] {
        let (n, base) = Self.shapes[p.type]
        var c = base
        for _ in 0..<(p.rot % 4) { c = c.map { (n - 1 - $0.1, $0.0) } }
        return c.map { ($0.0 + p.x, $0.1 + p.y) }
    }

    private func valid(_ p: Piece) -> Bool {
        for (x, y) in cells(p) {
            if x < 0 || x >= Self.cols || y >= Self.rows { return false }
            if y >= 0 && grid[y][x] != 0 { return false }
        }
        return true
    }

    private func spawn() {
        current = Piece(type: next, rot: 0, x: 3, y: 0)
        next = Int.random(in: 0..<7)
        if !valid(current) { over = true }
    }

    private func lock() {
        for (x, y) in cells(current) where y >= 0 { grid[y][x] = current.type + 1 }
        let remaining = grid.filter { $0.contains(0) }
        let cleared = Self.rows - remaining.count
        if cleared > 0 {
            grid = [[Int]](repeating: [Int](repeating: 0, count: Self.cols), count: cleared) + remaining
            lines += cleared
            score += [0, 100, 300, 500, 800][min(4, cleared)] * level
            level = 1 + lines / 10
        }
        spawn()
    }

    private func move(_ dx: Int, _ dy: Int) -> Bool {
        var p = current
        p.x += dx; p.y += dy
        if valid(p) { current = p; return true }
        return false
    }

    func reset() {
        grid = [[Int]](repeating: [Int](repeating: 0, count: Self.cols), count: Self.rows)
        score = 0; lines = 0; level = 1; over = false; acc = 0
        spawn()
    }

    func press(_ key: KeyID) {
        if over {
            if key == .enter { reset() }
            return
        }
        switch key {
        case .left: _ = move(-1, 0)
        case .right: _ = move(1, 0)
        case .down: if !move(0, 1) { lock() }; acc = 0
        case .up:
            var p = current
            p.rot += 1
            for kick in [0, -1, 1, -2, 2] {
                var q = p; q.x += kick
                if valid(q) { current = q; break }
            }
        case .enter:
            while move(0, 1) {}
            lock()
            acc = 0
        default: break
        }
    }

    func update(now: TimeInterval) {
        guard let l = last else { last = now; return }
        let dt = min(now - l, 0.1)
        last = now
        if over { return }
        acc += dt
        let interval = max(0.08, 0.75 - 0.06 * Double(level - 1))
        if acc >= interval {
            acc = 0
            if !move(0, 1) { lock() }
        }
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.06, green: 0.06, blue: 0.1)))
        let cell: CGFloat = 10.5
        let wellX: CGFloat = 104, wellY: CGFloat = 4
        let wellRect = CGRect(x: wellX - 1, y: wellY - 1, width: cell * CGFloat(Self.cols) + 2, height: cell * CGFloat(Self.rows) + 2)
        ctx.fill(Path(wellRect), with: .color(.black))
        ctx.stroke(Path(wellRect), with: .color(.white.opacity(0.7)), lineWidth: 1)

        func drawCell(_ x: Int, _ y: Int, _ type: Int, alpha: Double = 1) {
            let r = CGRect(x: wellX + CGFloat(x) * cell, y: wellY + CGFloat(y) * cell, width: cell, height: cell)
            ctx.fill(Path(r.insetBy(dx: 0.5, dy: 0.5)), with: .color(Self.colors[type].opacity(alpha)))
            ctx.fill(Path(CGRect(x: r.minX + 2, y: r.minY + 2, width: cell - 4, height: 2)), with: .color(.white.opacity(0.35 * alpha)))
        }
        for y in 0..<Self.rows { for x in 0..<Self.cols where grid[y][x] != 0 { drawCell(x, y, grid[y][x] - 1) } }
        if !over {
            // ghost
            var g = current
            while true { var q = g; q.y += 1; if valid(q) { g = q } else { break } }
            for (x, y) in cells(g) where y >= 0 { drawCell(x, y, current.type, alpha: 0.25) }
            for (x, y) in cells(current) where y >= 0 { drawCell(x, y, current.type) }
        }

        // Side panel
        ctx.drawText("SCORE", at: CGPoint(x: 8, y: 10), size: 11)
        ctx.drawText("\(score)", at: CGPoint(x: 8, y: 24), size: 13, color: .yellow)
        ctx.drawText("LEVEL", at: CGPoint(x: 8, y: 52), size: 11)
        ctx.drawText("\(level)", at: CGPoint(x: 8, y: 66), size: 13, color: .yellow)
        ctx.drawText("LINES", at: CGPoint(x: 8, y: 94), size: 11)
        ctx.drawText("\(lines)", at: CGPoint(x: 8, y: 108), size: 13, color: .yellow)
        ctx.drawText("NEXT", at: CGPoint(x: 228, y: 10), size: 11)
        let (n, base) = Self.shapes[next]
        for (x, y) in base {
            let r = CGRect(x: 228 + CGFloat(x) * 9 + CGFloat(4 - n) * 4, y: 28 + CGFloat(y) * 9, width: 9, height: 9)
            ctx.fill(Path(r.insetBy(dx: 0.5, dy: 0.5)), with: .color(Self.colors[next]))
        }
        ctx.drawText("←→ move", at: CGPoint(x: 228, y: 150), size: 9, weight: .regular, color: .gray)
        ctx.drawText("↑ rotate", at: CGPoint(x: 228, y: 162), size: 9, weight: .regular, color: .gray)
        ctx.drawText("↓ drop", at: CGPoint(x: 228, y: 174), size: 9, weight: .regular, color: .gray)
        ctx.drawText("enter slam", at: CGPoint(x: 228, y: 186), size: 9, weight: .regular, color: .gray)
        ctx.drawText("clear quit", at: CGPoint(x: 228, y: 198), size: 9, weight: .regular, color: .gray)

        if over {
            ctx.fill(Path(CGRect(x: wellX, y: 80, width: cell * CGFloat(Self.cols), height: 50)), with: .color(.black.opacity(0.85)))
            ctx.drawText("GAME OVER", at: CGPoint(x: wellX + cell * 5, y: 96), size: 14, color: .red, anchor: .center)
            ctx.drawText("enter=retry", at: CGPoint(x: wellX + cell * 5, y: 116), size: 10, anchor: .center)
        }
    }
}
