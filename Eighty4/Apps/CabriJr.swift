import SwiftUI

/// Cabri Jr: point / segment / line / circle / triangle construction with a cursor, plus distance measure.
final class CabriJrApp: Game {
    let title = "CABRI JR"
    private(set) var wantsExit = false
    let handlesClear = true

    private enum Tool: Int, CaseIterable { case point, segment, line, circle, triangle }
    private var tool: Tool = .point
    private var cursor = CGPoint(x: 160, y: 100)
    private var points: [CGPoint] = []
    private var segments: [(Int, Int)] = []
    private var lines: [(Int, Int)] = []
    private var circles: [(Int, Int)] = []
    private var triangles: [(Int, Int, Int)] = []
    private var pending: [Int] = []
    private var menu: Int? = nil        // 1 file, 2 tools, 3 measure
    private var menuRow = 0
    private var measure: String = ""
    private var measuring = false

    func update(now: TimeInterval) {}
    func press(_ key: KeyID) {}

    private func nearestPoint() -> Int? {
        var best: Int? = nil
        var bestD = 8.0
        for (i, p) in points.enumerated() {
            let d = hypot(p.x - cursor.x, p.y - cursor.y)
            if d < bestD { bestD = d; best = i }
        }
        return best
    }

    private func place() -> Int {
        if let i = nearestPoint() { return i }
        points.append(cursor)
        return points.count - 1
    }

    func handle(_ key: KeyID, _ action: KeyAction) {
        if let m = menu {
            let count = m == 1 ? 2 : (m == 2 ? 5 : 1)
            switch action {
            case .up: menuRow = (menuRow + count - 1) % count
            case .down: menuRow = (menuRow + 1) % count
            case .enter: selectMenu(m, menuRow); menu = nil
            case .clear: menu = nil
            default:
                if let d = AppUI.digit(action), d >= 1, d <= count { selectMenu(m, d - 1); menu = nil }
            }
            return
        }
        if let f = AppUI.fkey(key) {
            if f <= 3 { menu = f; menuRow = 0 }
            if f == 5 { pending = []; measuring = false }
            return
        }
        let step: CGFloat = 4
        switch action {
        case .left: cursor.x = max(0, cursor.x - step)
        case .right: cursor.x = min(320, cursor.x + step)
        case .up: cursor.y = max(0, cursor.y - step)
        case .down: cursor.y = min(200, cursor.y + step)
        case .enter:
            let i = place()
            if measuring {
                pending.append(i)
                if pending.count == 2 {
                    let a = points[pending[0]], b = points[pending[1]]
                    measure = "D=\(AppUI.short(Double(hypot(a.x - b.x, a.y - b.y)) / 10, 2))"
                    pending = []; measuring = false
                }
                return
            }
            switch tool {
            case .point: break
            case .segment, .line, .circle:
                pending.append(i)
                if pending.count == 2 {
                    if tool == .segment { segments.append((pending[0], pending[1])) }
                    else if tool == .line { lines.append((pending[0], pending[1])) }
                    else { circles.append((pending[0], pending[1])) }
                    pending = []
                }
            case .triangle:
                pending.append(i)
                if pending.count == 3 { triangles.append((pending[0], pending[1], pending[2])); pending = [] }
            }
        case .clear: if pending.isEmpty { wantsExit = true } else { pending = [] }
        default: break
        }
    }

    private func selectMenu(_ m: Int, _ i: Int) {
        switch m {
        case 1:
            if i == 0 { points = []; segments = []; lines = []; circles = []; triangles = []; pending = []; measure = "" } else { wantsExit = true }
        case 2:
            tool = Tool(rawValue: i) ?? .point
            pending = []
        default:
            measuring = true; pending = []
        }
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        var p = Path()
        for (a, b) in segments { p.move(to: points[a]); p.addLine(to: points[b]) }
        for (a, b) in lines {
            let d = CGPoint(x: points[b].x - points[a].x, y: points[b].y - points[a].y)
            let len = max(1, hypot(d.x, d.y))
            let u = CGPoint(x: d.x / len * 600, y: d.y / len * 600)
            p.move(to: CGPoint(x: points[a].x - u.x, y: points[a].y - u.y)); p.addLine(to: CGPoint(x: points[a].x + u.x, y: points[a].y + u.y))
        }
        for (a, b, c) in triangles { p.move(to: points[a]); p.addLine(to: points[b]); p.addLine(to: points[c]); p.closeSubpath() }
        for (c, r) in circles {
            let rad = hypot(points[r].x - points[c].x, points[r].y - points[c].y)
            p.addEllipse(in: CGRect(x: points[c].x - rad, y: points[c].y - rad, width: rad * 2, height: rad * 2))
        }
        ctx.stroke(p, with: .color(.black), lineWidth: 1.2)
        for (i, pt) in points.enumerated() {
            ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 2, y: pt.y - 2, width: 4, height: 4)), with: .color(pending.contains(i) ? .red : .black))
        }
        var cross = Path()
        cross.move(to: CGPoint(x: cursor.x - 5, y: cursor.y)); cross.addLine(to: CGPoint(x: cursor.x + 5, y: cursor.y))
        cross.move(to: CGPoint(x: cursor.x, y: cursor.y - 5)); cross.addLine(to: CGPoint(x: cursor.x, y: cursor.y + 5))
        ctx.stroke(cross, with: .color(GraphRenderer.color(1)), lineWidth: 1.5)
        let toolName = measuring ? "MEASURE" : ["POINT", "SEGMENT", "LINE", "CIRCLE", "TRIANGLE"][tool.rawValue]
        ctx.drawText(toolName + (pending.isEmpty ? "" : " (\(pending.count))") + "  " + measure, at: CGPoint(x: 2, y: 2), size: 10, weight: .regular, color: .black)
        AppUI.softkeys(&ctx, ["FILE", "TOOLS", "MEASURE", "", "ESC"], size: size)
        if let m = menu {
            let items = m == 1 ? ["New", "Quit"] : (m == 2 ? ["Point", "Segment", "Line", "Circle", "Triangle"] : ["D.&Length"])
            let x = CGFloat(m - 1) * size.width / 5
            let h = CGFloat(items.count) * 14 + 4
            ctx.fill(Path(CGRect(x: x, y: size.height - 16 - h, width: 90, height: h)), with: .color(.white))
            ctx.stroke(Path(CGRect(x: x, y: size.height - 16 - h, width: 90, height: h)), with: .color(.black), lineWidth: 1)
            for (i, item) in items.enumerated() {
                let y = size.height - 16 - h + 2 + CGFloat(i) * 14
                if i == menuRow { ctx.fill(Path(CGRect(x: x + 1, y: y, width: 88, height: 14)), with: .color(.black)) }
                ctx.drawText("\(i + 1):\(item)", at: CGPoint(x: x + 4, y: y + 1), size: 10, weight: .regular, color: i == menuRow ? .white : .black)
            }
        }
    }
}
