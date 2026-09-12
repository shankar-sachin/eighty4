import SwiftUI

/// TI-84 Evo icon home screen: a grid of app tiles, three rows at a time, with the selected app's
/// name shown up in the header bar. A small arrow marks that the grid scrolls.
struct IconHomeView: View {
    @Environment(CalculatorState.self) private var state

    private let tile: CGFloat = 58
    private let rowsShown = 3

    var body: some View {
        let icons = HomeIcon.allCases
        let selected = min(state.iconIndex, icons.count - 1)
        let rowCount = (icons.count + HomeIcon.columns - 1) / HomeIcon.columns
        let selRow = selected / HomeIcon.columns
        let first = max(0, min(selRow - rowsShown + 1, rowCount - rowsShown))
        let colW = LCD.width / CGFloat(HomeIcon.columns)
        let rowH = LCD.bodyHeight / CGFloat(rowsShown)
        ZStack(alignment: .topLeading) {
            Color.white
            ForEach(icons) { icon in
                let r = icon.row - max(0, first)
                if r >= 0, r < rowsShown {
                    IconTile(icon: icon, selected: icon.rawValue == selected, size: tile)
                        .position(x: CGFloat(icon.col) * colW + colW / 2, y: CGFloat(r) * rowH + rowH / 2)
                }
            }
            if first + rowsShown < rowCount {
                Image(systemName: "arrow.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: 0x8A8A8A))
                    .position(x: LCD.width - 10, y: LCD.bodyHeight - 10)
            }
            if first > 0 {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: 0x8A8A8A))
                    .position(x: LCD.width - 10, y: 10)
            }
        }
        .frame(width: LCD.width, height: LCD.bodyHeight, alignment: .topLeading)
    }
}

/// One app tile: pale rounded square with blue-and-green art, filled blue when it is the selection.
struct IconTile: View {
    let icon: HomeIcon
    let selected: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? LCD.evoBlue : Color(hex: 0xEDEFF2))
            Image(systemName: icon.symbol)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(selected ? Color.white : icon.artColor)
        }
        .frame(width: size, height: size)
    }
}

/// One Help page: 10 text lines plus a page footer.
struct HelpScreenView: View {
    let page: Int

    var body: some View {
        let lines = HelpPages.pages[min(page, HelpPages.pages.count - 1)]
        ZStack(alignment: .topLeading) {
            ForEach(Array(lines.prefix(LCD.rows).enumerated()), id: \.offset) { i, line in
                Cells(row: i, col: 0, text: String(line.prefix(LCD.cols)), inverted: i == 0, color: Color(hex: 0x1A1A1A))
            }
        }
    }
}
