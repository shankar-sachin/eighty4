import SwiftUI

struct GraphScreenView: View {
    @Environment(CalculatorState.self) private var state

    var body: some View {
        let store = state.store
        let w = GraphWindow(store: store)
        Canvas { ctx, size in
            guard w.isValid else { return }
            drawGrid(&ctx, size, w, store)
            drawFunctions(&ctx, size, store)
            drawPlots(&ctx, size, w, store)
            drawDrawings(&ctx, size, w, store)
            drawCursorAndText(&ctx, size, w, store)
        }
        .frame(width: LCD.width, height: LCD.bodyHeight)
    }

    private func drawGrid(_ ctx: inout GraphicsContext, _ size: CGSize, _ w: GraphWindow, _ store: VariableStore) {
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

    private func drawFunctions(_ ctx: inout GraphicsContext, _ size: CGSize, _ store: VariableStore) {
        let width: CGFloat = store.thickLines ? 2 : 1
        for (n, pts) in state.graphSamples.sorted(by: { $0.key < $1.key }) {
            let (r, g, b) = Graphing.functionColor(n)
            let color = Color(red: r, green: g, blue: b)
            if store.dottedLines {
                for p in pts.compactMap({ $0 }) where p.y >= -2 && p.y <= size.height + 2 {
                    ctx.fill(Path(CGRect(x: p.x - width / 2, y: p.y - width / 2, width: width, height: width)), with: .color(color))
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

    private func drawPlots(_ ctx: inout GraphicsContext, _ size: CGSize, _ w: GraphWindow, _ store: VariableStore) {
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

    private func drawDrawings(_ ctx: inout GraphicsContext, _ size: CGSize, _ w: GraphWindow, _ store: VariableStore) {
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
            case .horizontal(let y):
                p.move(to: CGPoint(x: 0, y: w.py(y, size))); p.addLine(to: CGPoint(x: size.width, y: w.py(y, size)))
            case .vertical(let x):
                p.move(to: CGPoint(x: w.px(x, size), y: 0)); p.addLine(to: CGPoint(x: w.px(x, size), y: size.height))
            case .function(let text):
                var pen = false
                for col in 0..<Int(size.width) {
                    let x = w.xAt(column: col, size)
                    if let y = Graphing.evaluate(text, at: x, store: store) {
                        let pt = CGPoint(x: CGFloat(col), y: w.py(y, size))
                        if pen { p.addLine(to: pt) } else { p.move(to: pt); pen = true }
                    } else { pen = false }
                }
            case .text(let row, let col, let s):
                ctx.drawText(s, at: CGPoint(x: col, y: row), size: 9, weight: .regular, color: .black)
                continue
            }
            ctx.stroke(p, with: .color(.black), lineWidth: 1)
        }
    }

    private func drawCursorAndText(_ ctx: inout GraphicsContext, _ size: CGSize, _ w: GraphWindow, _ store: VariableStore) {
        let fmt: (Double) -> String = { ResultFormatter.number($0, notation: store.notation, fixed: store.fixedDigits) }
        let showCursor: Bool = { if case .view = state.graphMode { return false }; return true }()
        guard showCursor else { return }
        let sub = Tokenizer.subscripts
        let x = state.traceX
        let y = Graphing.y(state.traceFn, at: x, store: store)
        if let y = y {
            let p = CGPoint(x: w.px(x, size), y: w.py(y, size))
            var c = Path()
            c.move(to: CGPoint(x: p.x - 5, y: p.y)); c.addLine(to: CGPoint(x: p.x + 5, y: p.y))
            c.move(to: CGPoint(x: p.x, y: p.y - 5)); c.addLine(to: CGPoint(x: p.x, y: p.y + 5))
            ctx.stroke(c, with: .color(.black), lineWidth: 1.5)
            ctx.stroke(Path(CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)), with: .color(.white), lineWidth: 1)
        }
        // Expression (top-left) like ExprOn
        if store.exprOn, let text = store.yFuncs[state.traceFn] {
            let (r, g, b) = Graphing.functionColor(state.traceFn)
            let label = "Y\(sub[state.traceFn])=\(text)"
            ctx.fill(Path(CGRect(x: 0, y: 0, width: CGFloat(label.count) * 7.2 + 4, height: 14)), with: .color(.white.opacity(0.85)))
            ctx.drawText(label, at: CGPoint(x: 2, y: 1), size: 11, weight: .regular, color: Color(red: r, green: g, blue: b))
        }
        // Bottom line: prompt or coordinates
        let bottomY = size.height - 15
        ctx.fill(Path(CGRect(x: 0, y: bottomY - 1, width: size.width, height: 16)), with: .color(.white.opacity(0.85)))
        if let prompt = state.calcPrompt {
            ctx.drawText(prompt, at: CGPoint(x: 2, y: bottomY), size: 11, weight: .regular, color: .black)
            let typed = state.graphBuffer.isEmpty ? "" : String(state.graphBuffer)
            let xText = typed.isEmpty ? "X=\(fmt(x))" : "X=\(typed)"
            let yText = y.map { "Y=\(fmt($0))" } ?? ""
            ctx.drawText(xText, at: CGPoint(x: 100, y: bottomY), size: 11, weight: .regular, color: .black)
            ctx.drawText(yText, at: CGPoint(x: 210, y: bottomY), size: 11, weight: .regular, color: .black)
        } else if let r = state.calcResult {
            if !r.label.isEmpty { ctx.drawText(r.label, at: CGPoint(x: 2, y: bottomY), size: 11, weight: .regular, color: .black) }
            let lx: CGFloat = r.label.isEmpty ? 2 : 100
            ctx.drawText("X=\(fmt(r.x))", at: CGPoint(x: lx, y: bottomY), size: 11, weight: .regular, color: .black)
            ctx.drawText("Y=\(fmt(r.y))", at: CGPoint(x: 210, y: bottomY), size: 11, weight: .regular, color: .black)
        } else if store.coordOn {
            let typed = state.graphBuffer.isEmpty ? fmt(x) : String(state.graphBuffer)
            ctx.drawText("X=\(typed)", at: CGPoint(x: 2, y: bottomY), size: 11, weight: .regular, color: .black)
            if let y = y { ctx.drawText("Y=\(fmt(y))", at: CGPoint(x: 170, y: bottomY), size: 11, weight: .regular, color: .black) }
        }
    }
}

struct TableScreenView: View {
    @Environment(CalculatorState.self) private var state

    private let colWidth = 8
    private let dataRows = 8

    var body: some View {
        let store = state.store
        let sub = Tokenizer.subscripts
        let defined = Graphing.definedFunctions(store)
        let dt = store.numbers["ΔTbl"] ?? 1
        let firstFn = max(0, min(state.tableCol - 2, defined.count - 2))
        let fnCols = Array(defined.dropFirst(max(0, firstFn)).prefix(2))
        let fmt: (Double) -> String = { String(ResultFormatter.number($0, notation: store.notation, fixed: store.fixedDigits).prefix(self.colWidth - 1)) }
        ZStack(alignment: .topLeading) {
            Cells(row: 0, col: 3, text: "X", inverted: state.tableCol == 0)
            ForEach(Array(fnCols.enumerated()), id: \.offset) { i, n in
                Cells(row: 0, col: (i + 1) * colWidth + 3, text: "Y\(sub[n])", inverted: state.tableCol == defined.firstIndex(of: n).map { $0 + 1 })
            }
            ForEach(0..<dataRows, id: \.self) { r in
                let x = state.tableStart + Double(r) * dt
                let xText = fmt(x)
                Cells(row: r + 1, col: 0, text: String(repeating: " ", count: max(0, colWidth - 1 - xText.count)) + xText, inverted: state.tableRow == r && state.tableCol == 0)
                ForEach(Array(fnCols.enumerated()), id: \.offset) { i, n in
                    let yText = Graphing.y(n, at: x, store: store).map(fmt) ?? "ERROR"
                    let colIndex = (defined.firstIndex(of: n) ?? 0) + 1
                    Cells(row: r + 1, col: (i + 1) * colWidth, text: String(repeating: " ", count: max(0, colWidth - 1 - yText.count)) + yText, inverted: state.tableRow == r && state.tableCol == colIndex)
                }
            }
            let bottom: String = {
                let x = state.tableStart + Double(state.tableRow) * dt
                if state.tableCol == 0 { return "X=\(ResultFormatter.number(x))" }
                guard state.tableCol - 1 < defined.count else { return "" }
                let n = defined[state.tableCol - 1]
                return "Y\(sub[n])=" + (Graphing.y(n, at: x, store: store).map { ResultFormatter.number($0) } ?? "ERROR")
            }()
            Cells(row: LCD.rows - 1, col: 0, text: String(bottom.prefix(LCD.cols)))
        }
    }
}
