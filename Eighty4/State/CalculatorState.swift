import SwiftUI
import Observation

struct LCDLine: Identifiable {
    let id = UUID()
    var text: String
    var trailing: Bool
}

@Observable
final class CalculatorState {
    enum Modifier { case none, second, alpha, alphaLock }

    static let columns = 26
    static let visibleRows = 10

    let store = VariableStore()

    // Home screen entry
    var entry: [Character] = []
    var cursor = 0
    var history: [LCDLine] = []
    var modifier: Modifier = .none
    var screen: Screen = .home
    var returnScreen: Screen = .home
    var insertMode = false
    var historyIndex: Int? = nil
    var rclPending = false
    var homeEntryBackup: [Character] = []
    var homeCursorBackup = 0

    // Shell / UI
    var showShellPicker = false
    var shell: ShellColor {
        didSet { UserDefaults.standard.set(shell.rawValue, forKey: "shell") }
    }

    // Menus
    var menuTab = 0
    var menuRow = 0

    // Settings / number editors
    var editorRow = 0
    var editorCol = 0
    var editorBuffer: [Character] = []
    var editorTyping = false
    var tvmSolved: String? = nil

    // Y= editor
    var yRow = 0

    // List editor
    var listRow = 0
    var listCol = 0

    // Matrix editor
    var matName = "A"
    var matRow = -1
    var matCol = 0

    // Graph
    var graphMode: GraphMode = .view
    var graphSamples: [Int: [CGPoint?]] = [:]
    var traceFn = 1
    var traceX = 0.0
    var calcStage = 0
    var calcBounds: [Double] = []
    var calcFns: [Int] = []
    var calcResult: CalcResult? = nil
    var graphBuffer: [Character] = []

    // Table
    var tableStart = 0.0
    var tableRow = 0
    var tableCol = 0

    // Apps
    var game: (any Game)? = nil

    init() {
        let raw = UserDefaults.standard.string(forKey: "shell") ?? ""
        shell = ShellColor(rawValue: raw) ?? .black
    }

    // MARK: - Home display model

    private var entryLineCount: Int { entry.count / Self.columns + 1 }

    var displayLines: [LCDLine] {
        var lines = history
        var chunks = Self.chunk(String(entry), Self.columns)
        while chunks.count < entryLineCount { chunks.append("") }
        lines += chunks.map { LCDLine(text: $0, trailing: false) }
        return Array(lines.suffix(Self.visibleRows))
    }

    var cursorCell: (row: Int, col: Int) {
        let total = history.count + entryLineCount
        let start = max(0, total - Self.visibleRows)
        return (history.count + cursor / Self.columns - start, cursor % Self.columns)
    }

    var cursorGlyph: String? {
        switch modifier {
        case .second: return "↑"
        case .alpha, .alphaLock: return "A"
        case .none: return nil
        }
    }

    static func chunk(_ s: String, _ n: Int) -> [String] {
        var out: [String] = []
        var cur = ""
        for ch in s {
            cur.append(ch)
            if cur.count == n { out.append(cur); cur = "" }
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    // MARK: - Entry editing

    func insert(_ s: String) {
        guard entry.count + s.count <= Self.columns * 8 else { return }
        for ch in s {
            if !insertMode, cursor < entry.count {
                entry[cursor] = ch
            } else {
                entry.insert(ch, at: cursor)
            }
            cursor += 1
        }
    }

    func deleteAtCursor() {
        if entry.isEmpty { return }
        if cursor < entry.count {
            entry.remove(at: cursor)
        } else {
            entry.removeLast()
            cursor = entry.count
        }
    }

    func appendHistory(expr: String, result: String) {
        for c in Self.chunk(expr, Self.columns) {
            history.append(LCDLine(text: c, trailing: false))
        }
        for line in result.split(separator: "\n", omittingEmptySubsequences: false) {
            history.append(LCDLine(text: String(line), trailing: true))
        }
        if history.count > 80 { history.removeFirst(history.count - 80) }
    }

    func fail(_ error: CalcError) {
        if case .error = screen { return }
        returnScreen = screen
        screen = .error(error.message)
    }

    func evaluate() {
        let text = entry.isEmpty ? (store.entries.last ?? "") : String(entry)
        guard !text.isEmpty else { return }
        if store.entries.last != text {
            store.entries.append(text)
            if store.entries.count > 40 { store.entries.removeFirst() }
        }
        historyIndex = nil
        do {
            let v = try Evaluator.evaluate(text, ctx: EvalContext(store: store))
            if case .str(let s) = v, s == "Done" {} else { store.ans = v }
            appendHistory(expr: text, result: ResultFormatter.format(v, store: store))
            entry = []
            cursor = 0
            if store.pendingClrHome { history = []; store.pendingClrHome = false }
            if store.pendingShowGraph { store.pendingShowGraph = false; openGraph(.view) }
        } catch let err as CalcError {
            fail(err)
        } catch {
            fail(.syntax)
        }
    }

    // MARK: - Info screens

    var aboutLines: [String] {
        ["", "      Eighty4 v0.2.0", "", "  TI-84 Plus CE replica", "  PROD#: 0E-84-CE-0002", "  ID: 84LT-0R00-0002", "", "  RAM FREE 154164", "  ARC FREE 3020K", "  Not affiliated with TI"]
    }

    var memLines: [String] {
        let listCount = store.lists.values.filter { !$0.isEmpty }.count
        let yCount = store.yFuncs.values.filter { !$0.isEmpty }.count
        return ["RAM FREE      154164", "ARC FREE       3020K", "",
                "1:All…", "2:Real…        \(store.reals.count)", "3:Complex…     0", "4:List…        \(listCount)",
                "5:Matrix…      \(store.matrices.count)", "6:Y-Vars…      \(yCount)", "7:Prgm…        2"]
    }
}
