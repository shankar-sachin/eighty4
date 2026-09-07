import SwiftUI

/// The 320×240 TI-84 Plus CE display, rendered at native size and scaled by the parent.
struct LCDView: View {
    @Environment(CalculatorState.self) private var state

    private let cellW: CGFloat = 12
    private let lineH: CGFloat = 21
    private let statusH: CGFloat = 22
    private let leftPad: CGFloat = 4
    private let fontSize: CGFloat = 17

    private var textFont: Font { .system(size: fontSize, weight: .regular, design: .monospaced) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            switch state.screen {
            case .off:
                Color(hex: 0x1B1D1C)
            case .home:
                VStack(spacing: 0) {
                    statusBar
                    homeLines
                }
            case .comingSoon:
                VStack(spacing: 0) {
                    statusBar
                    Spacer()
                    Text("Coming Soon")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.black)
                    Text("Eighty4")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x3E6FB0))
                        .padding(.top, 4)
                    Spacer()
                }
            case .error(let msg):
                VStack(alignment: .leading, spacing: 0) {
                    statusBar
                    row(msg, highlighted: true)
                    row("1:Quit", highlighted: false)
                    row("2:Goto", highlighted: false)
                }
            }
        }
        .frame(width: 320, height: 240)
        .clipped()
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 6) {
            Text("NORMAL FLOAT AUTO REAL RADIAN MP")
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(Color(hex: 0x2B2B2B))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            Group {
                switch state.modifier {
                case .second:
                    Text("↑").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: 0x2F6EC0))
                case .alpha, .alphaLock:
                    Text("A").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: 0x3B8A2A))
                case .none:
                    EmptyView()
                }
            }
            battery
        }
        .padding(.horizontal, 4)
        .frame(width: 320, height: statusH)
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

    // MARK: - Home screen

    private var homeLines: some View {
        let lines = state.displayLines
        let cursor = state.cursorCell
        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    textRow(line)
                }
            }
            TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                let on = Int(ctx.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
                cursorView
                    .opacity(on ? 1 : 0)
                    .offset(x: leftPad + CGFloat(cursor.col) * cellW, y: CGFloat(cursor.row) * lineH)
            }
        }
        .frame(width: 320, height: 240 - statusH, alignment: .topLeading)
    }

    private func textRow(_ line: LCDLine) -> some View {
        let chars = Array(line.text)
        let pad = max(0, CalculatorState.columns - chars.count)
        let cells: [Character] = line.trailing
            ? Array(repeating: " ", count: pad) + chars
            : chars + Array(repeating: " ", count: pad)
        return HStack(spacing: 0) {
            ForEach(Array(cells.prefix(CalculatorState.columns).enumerated()), id: \.offset) { _, ch in
                Text(String(ch))
                    .font(textFont)
                    .foregroundStyle(.black)
                    .frame(width: cellW, height: lineH)
            }
        }
        .padding(.leading, leftPad)
    }

    private func row(_ text: String, highlighted: Bool) -> some View {
        Text(text)
            .font(textFont)
            .foregroundStyle(highlighted ? .white : .black)
            .padding(.horizontal, 3)
            .frame(height: lineH)
            .background(highlighted ? Color.black : Color.clear)
            .padding(.leading, leftPad)
    }

    private var cursorView: some View {
        ZStack {
            Rectangle().fill(Color.black)
            switch state.modifier {
            case .second:
                Text("↑").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
            case .alpha, .alphaLock:
                Text("A").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
            case .none:
                if state.insertMode {
                    Rectangle().fill(Color.white).frame(height: lineH - 3).padding(.bottom, 3)
                }
            }
        }
        .frame(width: cellW, height: lineH)
    }
}
