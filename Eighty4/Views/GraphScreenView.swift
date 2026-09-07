import SwiftUI

/// Canvas drawing shared by the GRAPH screen and the graphing apps (Conics, Inequalz, Transfrm…).
enum GraphRenderer {
    static func color(_ n: Int) -> Color {
        let (r, g, b) = Graphing.functionColor(n)
        return Color(red: r, green: g, blue: b)
    }

    static func drawBackground(_ ctx: inout GraphicsContext, _ size: CGSize, _ store: VariableStore) {
        if let (r, g, b) = Graphing.backgroundColor(store.backgroundColor) {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: r, green: g, blue: b)))
        }
    }

    static func drawGrid(_ ctx: inout GraphicsContext, _ size: CGSize, _ w: GraphWindow, _ store: VariableStore) {
        let gridStyle = store.gridStyle
        if gridStyle != 0, w.xscl > 0, w.yscl > 0, (w.xmax - w.xmin) / w.xscl < 120, (w.ymax - w.ymin) / w.yscl < 120 {
            let xs = stride(from: ceil(w.xmin / w.xscl) * w.xscl, through: w.xmax, by: w.xscl)
            let ys = stride(from: ceil(w.ymin / w.yscl) * w.yscl, through: w.ymax, by: w.yscl)
            let color = Color(red: 0.75, green: 0.75, blue: 0.8)
            if gridStyle == 2 {
                var p = Path()
                for x in xs { p.move(to: CGPoint(x: w.px(x, size), y: 0)); p.addLine(to: CGPoint(x: w.px(x, size), y: size.height)) }
                for y in ys { p.move(to: CGPoint(x: 0, y: w.py(y, size))); p.addLine(to: CGPoint(x: size.width, y: w.py(y, size))) }
                ctx.stroke(p, with: .color(color), lineWidth: 0.5)
            } else {
                for x in xs { for y in ys {
                    ctx.fill(Path(CGRect(x: w.px(x, size) - 0.5, y: w.py(y, size) - 0.5, width: 1.2, height: 1.2)), with: .color(color))
                } }
            }
        }
        if store.axesOn {
            var p = Path()
            let x0 = w.px(0, size), y0 = w.py(0, size)
            p.move(to: CGPoint(x: 0, y: y0)); p.addLine(to: CGPoint(x: size.width, y: y0))
            p.move(to: CGPoint(x: x0, y: 0)); p.addLine(to: CGPoint(x: x0, y: size.height))
            ctx.stroke(p, with: .color(.black), lineWidth: 1)
            var ticks = Path()
            if w.xscl > 0, (w.xmax - w.xmin) / w.xscl < 200 {
                for x in stride(from: ceil(w.xmin / w.xscl) * w.xscl, through: w.xmax, by: w.xscl) {
                    ticks.move(to: CGPoint(x: w.px(x, size), y: y0 - 2)); ticks.addLine(to: CGPoint(x: w.px(x, size), y: y0 + 2))
                }
            }
            if w.yscl > 0, (w.ymax - w.ymin) / w.yscl < 200 {
                for y in stride(from: ceil(w.ymin / w.yscl) * w.yscl, through: w.ymax, by: w.yscl) {
                    ticks.move(to: CGPoint(x: x0 - 2, y: w.py(y, size))); ticks.addLine(to: CGPoint(x: x0 + 2, y: w.py(y, size)))
                }
            }
            ctx.stroke(ticks, with: .color(.black), lineWidth: 1)
            if store.labelOn {
                ctx.drawText("x", at: CGPoint(x: size.width - 10, y: y0 - 12), size: 10, color: .black)
                ctx.drawText("y", at: CGPoint(x: x0 + 4, y: 2), size: 10, color: .black)
            }
        }
    }

    static func drawSamples(_ ctx: inout GraphicsContext, _ size: CGSize, _ store: VariableStore, _ samples: [Int: [CGPoint?]]) {
        let width: CGFloat = store.thickLines ? 2 : 1
        let dots = store.dottedLines || store.graphType == .sequence
        for (n, pts) in samples.sorted(by: { $0.key < $1.key }) {
            let color = color(n)
            if dots {
                let s: CGFloat = store.graphType == .sequence ? 3 : width
                for p in pts.compactMap({ $0 }) where p.y >= -2 && p.y <= size.height + 2 {
                    ctx.fill(Path(CGRect(x: p.x - s / 2, y: p.y - s / 2, width: s, height: s)), with: .color(color))
                }
                continue
            }
            var path = Path()
            var pen = false
            for p in pts {
                if let p = p {
                    if pen { path.addLine(to: p) } else { path.move(to: p); pen = true }
                } else { pen = false }
            }
            ctx.stroke(path, with: .color(color), lineWidth: width)
        }
    }

    static func drawPlots(_ ctx: inout GraphicsContext, _ size: CGSize, _ w: GraphWindow, _ store: VariableStore) {
        for i in 1...3 where store.plotOn(i) {
            let (xs, ys) = Graphing.plotLists(store, i)
            let colorIdx = store.options["plot\(i)Color", default: i - 1]
            let colors: [Color] = [Color(red: 0.05, green: 0.35, blue: 0.85), .red, .black, Color(red: 0.8, green: 0.1, blue: 0.7), Color(red: 0.1, green: 0.6, blue: 0.15)]
            let color = colors[min(colorIdx, colors.count - 1)]
            let mark = store.options["plot\(i)Mark", default: 0]
            let type = store.options["plot\(i)Type", default: 0]
            var linePath = Path()
            for (k, (x, y)) in zip(xs, ys).enumerated() {
                let p = CGPoint(x: w.px(x, size), y: w.py(y, size))
                switch mark {
                case 1:
                    var c = Path(); c.move(to: CGPoint(x: p.x - 3, y: p.y)); c.addLine(to: CGPoint(x: p.x + 3, y: p.y))
                    c.move(to: CGPoint(x: p.x, y: p.y - 3)); c.addLine(to: CGPoint(x: p.x, y: p.y + 3))
                    ctx.stroke(c, with: .color(color), lineWidth: 1.5)
                case 2:
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3)), with: .color(color))
                default:
                    ctx.stroke(Path(CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)), with: .color(color), lineWidth: 1.5)
                }
                if type == 1 { if k == 0 { linePath.move(to: p) } else { linePath.addLine(to: p) } }
            }
            if type == 1 { ctx.stroke(linePath, with: .color(color), lineWidth: 1) }
        }
    }

    /// Polyline of an expression in X across the window.
    static func curve(_ text: String, _ size: CGSize, _ w: GraphWindow, _ store: VariableStore, swap: Bool = false) -> Path {
        var p = Path()
        var pen = false
        for col in 0..<Int(size.width) {
            let x = w.xAt(column: col, size)
            if let y = Graphing.evaluate(text, at: x, store: store) {
                let pt = swap ? CGPoint(x: w.px(y, size), y: w.py(x, size)) : CGPoint(x: CGFloat(col), y: w.py(y, size))
                if abs(pt.y) > 5000 || abs(pt.x) > 5000 { pen = false; continue }
                if pen { p.addLine(to: pt) } else { p.move(to: pt); pen = true }
            } else { pen = false }
        }
        return p
    }

    static func drawDrawings(_ ctx: inout GraphicsContext, _ size: CGSize, _ w: GraphWindow, _ store: VariableStore) {
        let fmt: (Double) -> String = { ResultFormatter.number($0) }
        for d in store.drawings {
            var p = Path()
            switch d {
            case .line(let x1, let y1, let x2, let y2):
                p.move(to: CGPoint(x: w.px(x1, size), y: w.py(y1, size))); p.addLine(to: CGPoint(x: w.px(x2, size), y: w.py(y2, size)))
            case .circle(let x, let y, let r):
                let rx = CGFloat(r / (w.xmax - w.xmin)) * size.width, ry = CGFloat(r / (w.ymax - w.ymin)) * size.height
                p.addEllipse(in: CGRect(x: w.px(x, size) - rx, y: w.py(y, size) - ry, width: rx * 2, height: ry * 2))
            case .point(let x, let y):
                p.addRect(CGRect(x: w.px(x, size) - 1.5, y: w.py(y, size) - 1.5, width: 3, height: 3))
            case .pixel(let row, let col):
                let sx = size.width / Graphing.tiPixels.width, sy = size.height / Graphing.tiPixels.height
                p.addRect(CGRect(x: CGFloat(col) * sx - 0.6, y: CGFloat(row) * sy - 0.6, width: max(1.2, sx), height: max(1.2, sy)))
            case .horizontal(let y):
                p.move(to: CGPoint(x: 0, y: w.py(y, size))); p.addLine(to: CGPoint(x: size.width, y: w.py(y, size)))
            case .vertical(let x):
                p.move(to: CGPoint(x: w.px(x, size), y: 0)); p.addLine(to: CGPoint(x: w.px(x, size), y: size.height))
            case .function(let text):
                p = curve(text, size, w, store)
            case .inverse(let text):
                p = curve(text, size, w, store, swap: true)
            case .tangent(let text, let x):
                let h = 1e-4
                guard let y0 = Graphing.evaluate(text, at: x, store: store),
                      let y1 = Graphing.evaluate(text, at: x + h, store: store), let y2 = Graphing.evaluate(text, at: x - h, store: store) else { continue }
                let m = (y1 - y2) / (2 * h)
                let b = y0 - m * x
                p.move(to: CGPoint(x: 0, y: w.py(m * w.xmin + b, size))); p.addLine(to: CGPoint(x: size.width, y: w.py(m * w.xmax + b, size)))
                ctx.fill(Path(CGRect(x: 0, y: size.height - 15, width: size.width, height: 15)), with: .color(.white.opacity(0.85)))
                ctx.drawText("y=\(fmt((m * 1e6).rounded() / 1e6))x+\(fmt((b * 1e6).rounded() / 1e6))", at: CGPoint(x: 2, y: size.height - 14), size: 11, weight: .regular, color: .black)
            case .shade(let lower, let upper, let xl, let xr):
                var fill = Path()
                let lo = xl ?? w.xmin, hi = xr ?? w.xmax
                for col in 0..<Int(size.width) {
                    let x = w.xAt(column: col, size)
                    guard x >= lo, x <= hi, let a = Graphing.evaluate(lower, at: x, store: store), let b = Graphing.evaluate(upper, at: x, store: store), b > a else { continue }
                    fill.addRect(CGRect(x: CGFloat(col), y: w.py(b, size), width: 1, height: w.py(a, size) - w.py(b, size)))
                }
                ctx.fill(fill, with: .color(Color(red: 0.05, green: 0.35, blue: 0.85).opacity(0.45)))
                continue
            case .dist(let kind, let params, let lo, let hi, let caption):
                var fill = Path()
                var curvePath = Path()
                var pen = false
                for col in 0..<Int(size.width) {
                    let x = w.xAt(column: col, size)
                    let y = Stats.distPDF(kind, params, x)
                    guard y.isFinite else { pen = false; continue }
                    let pt = CGPoint(x: CGFloat(col), y: w.py(y, size))
                    if pen { curvePath.addLine(to: pt) } else { curvePath.move(to: pt); pen = true }
                    if x >= lo, x <= hi { fill.addRect(CGRect(x: CGFloat(col), y: pt.y, width: 1, height: max(0, w.py(0, size) - pt.y))) }
                }
                ctx.fill(fill, with: .color(Color(red: 0.05, green: 0.35, blue: 0.85).opacity(0.5)))
                ctx.stroke(curvePath, with: .color(.black), lineWidth: 1)
                ctx.fill(Path(CGRect(x: 0, y: size.height - 15, width: size.width, height: 15)), with: .color(.white.opacity(0.85)))
                ctx.drawText(caption, at: CGPoint(x: 2, y: size.height - 14), size: 11, weight: .regular, color: .black)
                continue
            case .text(let row, let col, let s):
                ctx.drawText(s, at: CGPoint(x: col, y: row), size: 9, weight: .regular, color: .black)
                continue
            }
            ctx.stroke(p, with: .color(.black), lineWidth: 1)
        }
    }
}

struct GraphScreenView: View {
    @Environment(CalculatorState.self) private var state

    var body: some View {
        let store = state.store
        let w = GraphWindow(store: store)
        Canvas { ctx, size in
            guard w.isValid else { return }
            GraphRenderer.drawBackground(&ctx, size, store)
            GraphRenderer.drawGrid(&ctx, size, w, store)
            GraphRenderer.drawSamples(&ctx, size, store, state.graphSamples)
            GraphRenderer.drawPlots(&ctx, size, w, store)
            GraphRenderer.drawDrawings(&ctx, size, w, store)
            drawCursorAndText(&ctx, size, w, store)
        }
        .frame(width: LCD.width, height: LCD.bodyHeight)
    }

    private func drawCursorAndText(_ ctx: inout GraphicsContext, _ size: CGSize, _ w: GraphWindow, _ store: VariableStore) {
        let fmt: (Double) -> String = { ResultFormatter.number($0, notation: store.notation, fixed: store.fixedDigits) }
        let bottomY = size.height - 15
        func crosshair(_ p: CGPoint) {
            var c = Path()
            c.move(to: CGPoint(x: p.x - 5, y: p.y)); c.addLine(to: CGPoint(x: p.x + 5, y: p.y))
            c.move(to: CGPoint(x: p.x, y: p.y - 5)); c.addLine(to: CGPoint(x: p.x, y: p.y + 5))
            ctx.stroke(c, with: .color(.black), lineWidth: 1.5)
            ctx.stroke(Path(CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)), with: .color(.white), lineWidth: 1)
        }

        // Free cursor modes.
        if state.graphMode == .zbox || state.graphMode == .pen {
            let p = CGPoint(x: w.px(state.traceX, size), y: w.py(state.cursorY, size))
            if let (x1, y1) = state.zboxFirst {
                let q = CGPoint(x: w.px(x1, size), y: w.py(y1, size))
                ctx.stroke(Path(CGRect(x: min(p.x, q.x), y: min(p.y, q.y), width: abs(p.x - q.x), height: abs(p.y - q.y))), with: .color(.black), lineWidth: 1)
            }
            crosshair(p)
            ctx.fill(Path(CGRect(x: 0, y: bottomY - 1, width: size.width, height: 16)), with: .color(.white.opacity(0.85)))
            let label = state.graphMode == .pen ? (state.penDown ? "PEN DOWN" : "PEN UP") : (state.zboxFirst == nil ? "ZBox: 1st corner" : "ZBox: 2nd corner")
            ctx.drawText(label, at: CGPoint(x: 2, y: bottomY), size: 11, weight: .regular, color: .black)
            ctx.drawText("X=\(fmt(state.traceX))", at: CGPoint(x: 130, y: bottomY), size: 11, weight: .regular, color: .black)
            ctx.drawText("Y=\(fmt(state.cursorY))", at: CGPoint(x: 225, y: bottomY), size: 11, weight: .regular, color: .black)
            return
        }

        let showCursor: Bool = { if case .view = state.graphMode { return false }; return true }()
        guard showCursor else { return }
        let sub = Tokenizer.subscripts
        let p = state.traceX
        let pt = Graphing.point(state.traceFn, at: p, store: store)
        if let (x, y) = pt { crosshair(CGPoint(x: w.px(x, size), y: w.py(y, size))) }

        // Expression (top-left) like ExprOn
        if store.exprOn {
            let keys = Graphing.keys(for: state.traceFn, store)
            let text = keys.map { "\(CalculatorState.yLabel($0))\(store.funcText($0) ?? "")" }.joined(separator: " ")
            let label = store.graphType == .function ? "Y\(sub[state.traceFn])=\(store.yFuncs[state.traceFn] ?? "")" : text
            ctx.fill(Path(CGRect(x: 0, y: 0, width: CGFloat(label.count) * 7.2 + 4, height: 14)), with: .color(.white.opacity(0.85)))
            ctx.drawText(label, at: CGPoint(x: 2, y: 1), size: 11, weight: .regular, color: GraphRenderer.color(state.traceFn))
        }
        // Bottom line: prompt or coordinates
        ctx.fill(Path(CGRect(x: 0, y: bottomY - 1, width: size.width, height: 16)), with: .color(.white.opacity(0.85)))
        let pname = Graphing.parameterName(store)
        let typed = state.graphBuffer.isEmpty ? nil : String(state.graphBuffer)
        if let prompt = state.calcPrompt {
            ctx.drawText(prompt, at: CGPoint(x: 2, y: bottomY), size: 11, weight: .regular, color: .black)
            let xText = "X=" + (typed ?? fmt(pt?.0 ?? p))
            let yText = pt.map { "Y=\(fmt($0.1))" } ?? ""
            ctx.drawText(xText, at: CGPoint(x: 100, y: bottomY), size: 11, weight: .regular, color: .black)
            ctx.drawText(yText, at: CGPoint(x: 210, y: bottomY), size: 11, weight: .regular, color: .black)
        } else if let r = state.calcResult {
            if !r.label.isEmpty { ctx.drawText(r.label, at: CGPoint(x: 2, y: bottomY), size: 11, weight: .regular, color: .black) }
            let lx: CGFloat = r.label.isEmpty ? 2 : 100
            ctx.drawText("X=\(fmt(r.x))", at: CGPoint(x: lx, y: bottomY), size: 11, weight: .regular, color: .black)
            ctx.drawText("Y=\(fmt(r.y))", at: CGPoint(x: 210, y: bottomY), size: 11, weight: .regular, color: .black)
        } else if store.coordOn {
            if store.graphType == .function {
                ctx.drawText("X=\(typed ?? fmt(p))", at: CGPoint(x: 2, y: bottomY), size: 11, weight: .regular, color: .black)
                if let (_, y) = pt { ctx.drawText("Y=\(fmt(y))", at: CGPoint(x: 170, y: bottomY), size: 11, weight: .regular, color: .black) }
            } else {
                ctx.drawText("\(pname)=\(typed ?? fmt(p))", at: CGPoint(x: 2, y: bottomY), size: 11, weight: .regular, color: .black)
                if let (x, y) = pt {
                    ctx.drawText("X=\(fmt(x))", at: CGPoint(x: 110, y: bottomY), size: 11, weight: .regular, color: .black)
                    ctx.drawText("Y=\(fmt(y))", at: CGPoint(x: 215, y: bottomY), size: 11, weight: .regular, color: .black)
                }
            }
        }
    }
}

struct TableScreenView: View {
    @Environment(CalculatorState.self) private var state

    private let colWidth = 8
    private let dataRows = 8

    var body: some View {
        let store = state.store
        let columns = TableColumns.columns(store)
        let dt = store.graphType == .sequence ? 1 : (store.numbers["ΔTbl"] ?? 1)
        let firstFn = max(0, min(state.tableCol - 2, columns.count - 2))
        let shown = Array(columns.enumerated().dropFirst(max(0, firstFn)).prefix(2))
        let fmt: (Double) -> String = { String(ResultFormatter.number($0, notation: store.notation, fixed: store.fixedDigits).prefix(self.colWidth - 1)) }
        let pname = Graphing.parameterName(store)
        ZStack(alignment: .topLeading) {
            Cells(row: 0, col: 3, text: pname, inverted: state.tableCol == 0)
            ForEach(Array(shown.enumerated()), id: \.offset) { i, c in
                Cells(row: 0, col: (i + 1) * colWidth + 3, text: c.element.label, inverted: state.tableCol == c.offset + 1)
            }
            ForEach(0..<dataRows, id: \.self) { r in
                let x = state.tableStart + Double(r) * dt
                let xText = fmt(x)
                Cells(row: r + 1, col: 0, text: String(repeating: " ", count: max(0, colWidth - 1 - xText.count)) + xText, inverted: state.tableRow == r && state.tableCol == 0)
                ForEach(Array(shown.enumerated()), id: \.offset) { i, c in
                    let yText = c.element.value(x).map(fmt) ?? "ERROR"
                    Cells(row: r + 1, col: (i + 1) * colWidth, text: String(repeating: " ", count: max(0, colWidth - 1 - yText.count)) + yText, inverted: state.tableRow == r && state.tableCol == c.offset + 1)
                }
            }
            let bottom: String = {
                let x = state.tableStart + Double(state.tableRow) * dt
                if state.tableCol == 0 { return "\(pname)=\(ResultFormatter.number(x))" }
                guard state.tableCol - 1 < columns.count else { return "" }
                let c = columns[state.tableCol - 1]
                return c.label + "=" + (c.value(x).map { ResultFormatter.number($0) } ?? "ERROR")
            }()
            Cells(row: LCD.rows - 1, col: 0, text: String(bottom.prefix(LCD.cols)))
        }
    }
}
