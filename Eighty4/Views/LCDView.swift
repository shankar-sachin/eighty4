import SwiftUI

/// Native LCD geometry (320×240) and the character-cell grid used by every text screen.
enum LCD {
    static let cols = 26
    static let rows = 10
    static let cellW: CGFloat = 12
    static let lineH: CGFloat = 21
    static let statusH: CGFloat = 22
    static let leftPad: CGFloat = 4
    static let width: CGFloat = 320
    static let height: CGFloat = 240
    static var bodyHeight: CGFloat { height - statusH }
    static let font = Font.system(size: 17, weight: .regular, design: .monospaced)
    static let smallFont = Font.system(size: 12, weight: .regular, design: .monospaced)
}

/// A run of character cells. `inverted` draws white-on-black, `outlined` draws a cursor box.
struct CellText: View {
    let text: String
    var inverted = false
    var outlined = false
    var color: Color = .black

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                Text(MathGlyph.text(ch))
                    .font(LCD.font)
                    .foregroundStyle(inverted ? Color.white : color)
                    .frame(width: LCD.cellW, height: LCD.lineH)
                    .background(inverted ? Color.black : Color.clear)
            }
        }
        .overlay(outlined ? Rectangle().stroke(Color.black, lineWidth: 2) : nil)
    }
}

/// Cell text positioned at a (row, col) inside a top-leading ZStack.
struct Cells: View {
    let row: Int
    let col: Int
    let text: String
    var inverted = false
    var outlined = false
    var color: Color = .black

    var body: some View {
        CellText(text: text, inverted: inverted, outlined: outlined, color: color)
            .offset(x: LCD.leftPad + CGFloat(col) * LCD.cellW, y: CGFloat(row) * LCD.lineH)
    }
}

struct BlinkingCursor: View {
    let row: Int
    let col: Int
    var glyph: String? = nil
    var underline = false
    /// Exact cell position (x in cells, y in rows) when the cursor sits beside a stacked fraction.
    var at: (x: Double, y: Double)? = nil

    var body: some View {
        let x = at.map { $0.x } ?? Double(col)
        let y = at.map { $0.y } ?? Double(row)
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let on = Int(ctx.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            ZStack {
                if underline && glyph == nil {
                    Rectangle().fill(Color.black).frame(height: 3).offset(y: LCD.lineH / 2 - 2)
                } else {
                    Rectangle().fill(Color.black)
                }
                if let g = glyph {
                    Text(g).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                }
            }
            .frame(width: LCD.cellW, height: LCD.lineH)
            .opacity(on ? 1 : 0)
            .offset(x: LCD.leftPad + CGFloat(x) * LCD.cellW, y: CGFloat(y) * LCD.lineH)
        }
    }
}

/// How single characters draw in a cell; template delimiters fall back to flat punctuation.
enum MathGlyph {
    static func text(_ ch: Character) -> String {
        switch ch {
        case MathPrint.fracOpen: return "("
        case MathPrint.fracSep: return "/"
        case MathPrint.fracClose: return ")"
        case MathPrint.mixedOpen: return "_"
        case MathPrint.stackOpen: return "{"
        case MathPrint.rowSep: return ";"
        case MathPrint.colSep: return ","
        case MathPrint.stackClose: return "}"
        default: return String(ch)
        }
    }
}

/// One laid-out home-screen line: plain text, stacked fractions, piecewise braces.
struct MathLineView: View {
    let layout: MathLayout
    let row: Int
    var trailing = false
    var inverted = false

    var body: some View {
        let fg: Color = inverted ? .white : .black
        ZStack(alignment: .topLeading) {
            ForEach(Array(layout.rows.enumerated()), id: \.offset) { i, r in
                let top = CGFloat(row + layout.rowStart(i)) * LCD.lineH
                let left = LCD.leftPad + CGFloat(trailing ? LCD.cols - r.width : 0) * LCD.cellW
                if inverted {
                    Rectangle().fill(Color.black)
                        .frame(width: CGFloat(r.width) * LCD.cellW, height: CGFloat(r.height) * LCD.lineH)
                        .offset(x: left, y: top)
                }
                ForEach(Array(r.glyphs.enumerated()), id: \.offset) { _, g in
                    if g.placeholder {
                        Rectangle().stroke(fg, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                            .frame(width: LCD.cellW - 3, height: LCD.lineH - 6)
                            .offset(x: left + CGFloat(g.x) * LCD.cellW + 1.5, y: top + CGFloat(g.y) * LCD.lineH + 3)
                    } else {
                        Text(String(g.ch))
                            .font(LCD.font)
                            .foregroundStyle(fg)
                            .frame(width: LCD.cellW, height: LCD.lineH)
                            .offset(x: left + CGFloat(g.x) * LCD.cellW, y: top + CGFloat(g.y) * LCD.lineH)
                    }
                }
                ForEach(Array(r.bars.enumerated()), id: \.offset) { _, b in
                    Rectangle().fill(fg)
                        .frame(width: CGFloat(b.x1 - b.x0) * LCD.cellW, height: 1.5)
                        .offset(x: left + CGFloat(b.x0) * LCD.cellW, y: top + CGFloat(b.y) * LCD.lineH - 0.75)
                }
                ForEach(Array(r.braces.enumerated()), id: \.offset) { _, b in
                    BraceShape()
                        .stroke(fg, lineWidth: 1.5)
                        .frame(width: LCD.cellW, height: CGFloat(b.rows) * LCD.lineH)
                        .offset(x: left + CGFloat(b.x) * LCD.cellW, y: top + CGFloat(b.y) * LCD.lineH)
                }
            }
        }
    }
}

/// A left curly brace spanning its frame.
struct BraceShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midY = rect.midY, x0 = rect.minX + 3, x1 = rect.maxX - 3, xm = rect.midX
        p.move(to: CGPoint(x: x1, y: rect.minY + 1))
        p.addQuadCurve(to: CGPoint(x: xm, y: rect.minY + 6), control: CGPoint(x: xm, y: rect.minY + 1))
        p.addLine(to: CGPoint(x: xm, y: midY - 5))
        p.addQuadCurve(to: CGPoint(x: x0, y: midY), control: CGPoint(x: xm, y: midY))
        p.addQuadCurve(to: CGPoint(x: xm, y: midY + 5), control: CGPoint(x: xm, y: midY))
        p.addLine(to: CGPoint(x: xm, y: rect.maxY - 6))
        p.addQuadCurve(to: CGPoint(x: x1, y: rect.maxY - 1), control: CGPoint(x: xm, y: rect.maxY - 1))
        return p
    }
}

struct StatusBarView: View {
    @Environment(CalculatorState.self) private var state

    var body: some View {
        HStack(spacing: 6) {
            Text(state.store.statusText)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(Color(hex: 0x2B2B2B))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            switch state.modifier {
            case .second:
                Text("↑").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: 0x2F6EC0))
            case .alpha, .alphaLock:
                Text("A").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: 0x3B8A2A))
            case .none:
                EmptyView()
            }
            battery
        }
        .padding(.horizontal, 4)
        .frame(width: LCD.width, height: LCD.statusH)
        .background(Color(hex: 0xD9D9D9))
    }

    private var battery: some View {
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5).stroke(Color(hex: 0x2B2B2B), lineWidth: 1)
                    .frame(width: 20, height: 9)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(hex: 0x2F9E44))
                    .frame(width: 15, height: 6)
                    .padding(.leading, 1.5)
            }
            RoundedRectangle(cornerRadius: 0.5).fill(Color(hex: 0x2B2B2B)).frame(width: 2, height: 4)
        }
    }
}

/// The 320×240 display: status bar plus the active screen.
struct LCDView: View {
    @Environment(CalculatorState.self) private var state

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            if state.screen == .off {
                Color(hex: 0x1B1D1C)
            } else {
                VStack(spacing: 0) {
                    StatusBarView()
                    ZStack(alignment: .topLeading) {
                        content
                    }
                    .frame(width: LCD.width, height: LCD.bodyHeight, alignment: .topLeading)
                    .clipped()
                }
            }
        }
        .frame(width: LCD.width, height: LCD.height)
        .clipped()
    }

    @ViewBuilder
    private var content: some View {
        switch state.screen {
        case .home: HomeScreenView()
        case .error(let msg): ErrorScreenView(message: msg)
        case .menu(let id): MenuScreenView(id: id)
        case .editor(let id): SettingsEditorView(id: id)
        case .yEquals: YEqualsView()
        case .listEditor: ListEditorView()
        case .matrixEditor(let name): MatrixEditorView(name: name)
        case .graph: GraphScreenView()
        case .table: TableScreenView()
        case .message(let lines): TextScreenView(lines: lines)
        case .about: TextScreenView(lines: state.aboutLines)
        case .linkReceive: TextScreenView(lines: ["Waiting..."])
        case .app:
            if let g = state.game { AppScreenView(game: g) }
        case .solver: SolverView()
        case .varList(let m): VarListView(mode: m)
        case .confirm(let k): ConfirmView(kind: k)
        case .programEditor: ProgramEditorView()
        case .programName: NameEntryView(title: "PROGRAM")
        case .groupName: NameEntryView(title: "GROUP")
        case .programMenu(let title, let items): ProgramMenuView(title: title, items: items)
        case .off: EmptyView()
        }
    }
}

struct HomeScreenView: View {
    @Environment(CalculatorState.self) private var state

    var body: some View {
        let placed = state.placedLines
        let cursor = state.cursorPosition
        let selected = state.historySelection
        ZStack(alignment: .topLeading) {
            ForEach(Array(placed.enumerated()), id: \.offset) { _, p in
                MathLineView(layout: p.layout, row: p.row, trailing: p.line.trailing, inverted: selected != nil && p.line.group == selected)
            }
            if selected == nil, cursor.row >= 0, cursor.row < LCD.rows {
                BlinkingCursor(row: cursor.row, col: cursor.col, glyph: state.cursorGlyph, underline: state.insertMode, at: (cursor.x, cursor.y))
            }
        }
    }
}

struct ErrorScreenView: View {
    let message: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            Cells(row: 0, col: 0, text: message, inverted: true)
            Cells(row: 1, col: 0, text: "1:Quit")
            Cells(row: 2, col: 0, text: "2:Goto")
        }
    }
}

struct TextScreenView: View {
    let lines: [String]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(lines.prefix(LCD.rows).enumerated()), id: \.offset) { i, line in
                Cells(row: i, col: 0, text: String(line.prefix(LCD.cols)))
            }
        }
    }
}

struct AppScreenView: View {
    let game: any Game

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                game.update(now: tl.date.timeIntervalSinceReferenceDate)
                game.draw(&ctx, size: size)
            }
        }
        .frame(width: LCD.width, height: LCD.bodyHeight)
    }
}
