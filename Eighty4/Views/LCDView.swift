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
                Text(String(ch))
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

    var body: some View {
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
            .offset(x: LCD.leftPad + CGFloat(col) * LCD.cellW, y: CGFloat(row) * LCD.lineH)
        }
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
        let lines = state.displayLines
        let cursor = state.cursorCell
        ZStack(alignment: .topLeading) {
            ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                let pad = max(0, LCD.cols - line.text.count)
                let text = line.trailing ? String(repeating: " ", count: pad) + line.text : line.text
                Cells(row: i, col: 0, text: String(text.prefix(LCD.cols)))
            }
            BlinkingCursor(row: cursor.row, col: cursor.col, glyph: state.cursorGlyph, underline: state.insertMode)
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
