import SwiftUI

/// TI-style tabbed menu: tab strip on top, numbered items, selected index inverted.
struct MenuScreenView: View {
    @Environment(CalculatorState.self) private var state
    let id: MenuID

    var body: some View {
        let def = Menus.def(id, store: state.store)
        let tabIndex = min(state.menuTab, def.tabs.count - 1)
        let items = def.tabs[tabIndex].items
        let visible = LCD.rows - 1
        let start = max(0, min(state.menuRow - (visible - 1), max(0, items.count - visible)))
        ZStack(alignment: .topLeading) {
            tabStrip(def.tabs, selected: tabIndex)
            ForEach(0..<min(visible, max(0, items.count - start)), id: \.self) { i in
                let idx = start + i
                let item = items[idx]
                Cells(row: i + 1, col: 0, text: Menus.indexLabel(idx), inverted: idx == state.menuRow)
                Cells(row: i + 1, col: 1, text: ":" + String(item.label.prefix(LCD.cols - 2)))
            }
            if start + visible < items.count {
                Cells(row: LCD.rows - 1, col: LCD.cols - 1, text: "↓")
            }
            if start > 0 {
                Cells(row: 1, col: LCD.cols - 1, text: "↑")
            }
        }
    }

    @ViewBuilder
    private func tabStrip(_ tabs: [MenuTab], selected: Int) -> some View {
        let positions: [(Int, String)] = {
            var col = 0
            var out: [(Int, String)] = []
            for t in tabs {
                let title = String(t.title.prefix(12))
                out.append((col, title))
                col += title.count + 1
            }
            return out
        }()
        ForEach(Array(positions.enumerated()), id: \.offset) { i, p in
            Cells(row: 0, col: p.0, text: p.1, inverted: i == selected)
        }
    }
}
