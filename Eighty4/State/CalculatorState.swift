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
    static let version = "0.3.0"

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
    var cursorY = 0.0
    var zboxFirst: (Double, Double)? = nil
    var penDown = false
    var calcStage = 0
    var calcBounds: [Double] = []
    var calcFns: [Int] = []
    var calcResult: CalcResult? = nil
    var graphBuffer: [Character] = []

    // Table
    var tableStart = 0.0
    var tableRow = 0
    var tableCol = 0

    // Solver
    var solverStage = 0          // 0: eqn entry, 1: variable list
    var solverRow = 0
    var solverSolved: String? = nil

    // MEM variable lists
    var varListRow = 0

    // Programs
    var programName = ""
    var programLines: [String] = [""]
    var programRow = 0
    var programMenuRow = 0
    var nameBuffer: [Character] = []
    var runner: ProgramRunner? = nil
    var errorGoto: (String, Int)? = nil

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

    func appendLine(_ text: String, trailing: Bool) {
        let chunks = Self.chunk(text, Self.columns)
        if chunks.isEmpty { history.append(LCDLine(text: "", trailing: trailing)) }
        for c in chunks { history.append(LCDLine(text: c, trailing: trailing)) }
        if history.count > 80 { history.removeFirst(history.count - 80) }
    }

    /// Output(row, col, text): writes into the visible 10-line window.
    func outputAt(row: Int, col: Int, _ text: String) {
        guard row >= 1, row <= Self.visibleRows, col >= 1, col <= Self.columns else { return }
        while history.count < Self.visibleRows { history.append(LCDLine(text: "", trailing: false)) }
        let start = history.count - Self.visibleRows
        let idx = start + row - 1
        var chars = Array(history[idx].text)
        while chars.count < Self.columns { chars.append(" ") }
        var c = col - 1
        for ch in text where c < Self.columns { chars[c] = ch; c += 1 }
        history[idx] = LCDLine(text: String(chars), trailing: false)
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
        if ProgramRunner.isStatement(text) {
            for c in Self.chunk(text, Self.columns) { history.append(LCDLine(text: c, trailing: false)) }
            entry = []
            cursor = 0
            runProgram(lines: [text])
            return
        }
        do {
            let v = try Evaluator.evaluate(text, ctx: EvalContext(store: store))
            if case .str(let s) = v, s == "Done" {} else { store.ans = v }
            appendHistory(expr: text, result: ResultFormatter.format(v, store: store))
            entry = []
            cursor = 0
            if store.pendingClrHome { history = []; store.pendingClrHome = false }
            if let lines = store.pendingResults {
                store.pendingResults = nil
                screen = .message(Array(lines.prefix(10)))
                returnScreen = .home
            }
            if store.pendingShowGraph { store.pendingShowGraph = false; openGraph(.view) }
        } catch let err as CalcError {
            fail(err)
        } catch {
            fail(.syntax)
        }
    }

    // MARK: - Programs

    func runProgram(name: String? = nil, lines: [String]? = nil) {
        let host = ProgramRunner.Host(
            store: store,
            display: { [weak self] text, trailing in self?.appendLine(text, trailing: trailing) },
            output: { [weak self] r, c, s in self?.outputAt(row: r, col: c, s) },
            clearHome: { [weak self] in self?.history = [] },
            showGraph: { [weak self] in self?.openGraph(.view) },
            showTable: { [weak self] in self?.openTable() })
        let r = ProgramRunner(host: host)
        runner = r
        errorGoto = nil
        do {
            if let name = name { try r.start(program: name) } else { r.start(lines: lines ?? []) }
            try r.run()
            afterRunnerStep()
        } catch let e as CalcError { runnerFailed(e) } catch { runnerFailed(.syntax) }
    }

    func resumeRunner(input: String?) {
        guard let r = runner else { return }
        do {
            try r.resume(input: input)
            afterRunnerStep()
        } catch let e as CalcError { runnerFailed(e) } catch { runnerFailed(.syntax) }
    }

    private func afterRunnerStep() {
        guard let r = runner else { return }
        if r.isFinished, r.wait == .none {
            runner = nil
            if screen == .home || screen == .graph || screen == .table { if r.displayedSomething || r.lastValue == nil { appendLine("Done", trailing: true) } }
            entry = []; cursor = 0
            return
        }
        switch r.wait {
        case .input(_, let prompt):
            if screen != .home { screen = .home }
            appendLine(prompt, trailing: false)
            entry = []; cursor = 0
        case .menu(let title, let items, _):
            programMenuRow = 0
            screen = .programMenu(title, items)
            returnScreen = .home
        default:
            break
        }
    }

    private func runnerFailed(_ e: CalcError) {
        errorGoto = runner?.errorLocation
        runner = nil
        if screen != .home { screen = .home }
        fail(e)
    }

    func breakProgram() {
        runner = nil
        screen = .home
        fail(.breakKey)
    }

    // MARK: - Y= rows per graph mode

    var yKeys: [String] {
        switch store.graphType {
        case .function: return [1, 2, 3, 4, 5, 6, 7, 8, 9, 0].map { "Y\($0)" }
        case .parametric: return (1...6).flatMap { ["X\($0)T", "Y\($0)T"] }
        case .polar: return (1...6).map { "r\($0)" }
        case .sequence: return ["nMin", "u", "u(nMin)", "v", "v(nMin)", "w", "w(nMin)"]
        }
    }

    static func yLabel(_ key: String) -> String {
        if key == "nMin" { return "nMin=" }
        if key.hasSuffix("(nMin)") { return key + "=" }
        if key.count == 1 { return key + "(n)=" }
        return Tokenizer.namedFuncLabel(key) + "="
    }

    /// Rows that carry the "\" on/off marker (function rows, not initial values).
    static func hasToggle(_ key: String) -> Bool {
        if key == "nMin" || key.hasSuffix("(nMin)") { return false }
        if key.hasPrefix("Y"), key.hasSuffix("T") { return false }
        return true
    }

    // MARK: - Info screens

    var aboutLines: [String] {
        ["", "      Eighty4 v\(Self.version)", "", "  TI-84 Plus CE replica", "  PROD#: 0E-84-CE-0003", "  ID: 84LT-0R00-0003", "", "  RAM FREE \(MemoryModel.ramFree(store))", "  ARC FREE \(MemoryModel.arcFreeText(store))", "  Not affiliated with TI"]
    }

    /// Items shown by a MEM variable list.
    func varListItems(_ mode: VarListMode) -> [MemoryModel.Item] {
        let all = MemoryModel.items(store)
        switch mode {
        case .archive: return all.filter { !store.archived.contains($0.name) }
        case .unarchive: return all.filter { store.archived.contains($0.name) }
        case .manage(let cat):
            if cat == "All" { return all }
            if cat == "Apps" { return Menus.builtInPrograms.map { MemoryModel.Item(name: $0.0, category: "Apps", bytes: 16384) } }
            return all.filter { $0.category == cat }
        }
    }
}
