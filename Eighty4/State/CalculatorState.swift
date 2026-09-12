import SwiftUI
import Observation

struct LCDLine: Identifiable {
    let id = UUID()
    var text: String
    var trailing: Bool
    /// Full text pasted when this line is selected with ▲/▼ + ENTER; nil for non-selectable lines.
    var source: String? = nil
    /// Lines of one entry or answer share a group so they highlight together.
    var group: Int = -1
    /// An entry and its answer share a pair so DEL/CLEAR remove both.
    var pair: Int = -1
    /// The answer's value, so Ans can roll back when a pair is deleted.
    var value: Value? = nil
    /// Cell rows this line occupies (MathPrint fractions take two).
    var rows: Int = 1

    var layout: MathLayout {
        MathPrint.containsTemplate(text) ? MathLayout.layout(text, width: CalculatorState.columns)
                                         : MathLayout.layout(String(text.prefix(CalculatorState.columns)), width: CalculatorState.columns)
    }
}

/// A history line or the entry positioned on the home screen.
struct PlacedLine {
    let line: LCDLine
    /// Cell row of the line's top edge (may be negative when partly scrolled off).
    let row: Int
    let layout: MathLayout
}

@Observable
final class CalculatorState {
    enum Modifier { case none, second, alpha, alphaLock }

    static let columns = 26
    static let visibleRows = 10
    static let version = "1.1.0"

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
    /// Group of the history entry/answer highlighted with ▲/▼ (TI-84 Plus CE scroll-back).
    var historySelection: Int? = nil
    /// Lines the home screen is scrolled up from the bottom while a history item is selected.
    var homeScroll = 0
    private var nextGroup = 0
    /// Set while a hardware-keyboard key is being handled: typed text is linear, so it never opens MathPrint templates.
    @ObservationIgnored var hardwareTyping = false
    /// Letters typed in a row on a hardware keyboard; "sin" + "(" becomes the sin( token.
    @ObservationIgnored var hardwareWord = ""

    // Shell / UI
    var showShellPicker = false
    var shell: ShellColor {
        didSet { if VariableStore.persistenceEnabled { UserDefaults.standard.set(shell.rawValue, forKey: "shell") } }
    }
    /// Which calculator the app is being (TI-84 Plus CE or TI-84 Evo); persisted like the shell.
    var model: CalcModel {
        didSet {
            guard model != oldValue else { return }
            if VariableStore.persistenceEnabled { UserDefaults.standard.set(model.rawValue, forKey: "model") }
            store.evo = model == .evo
            if !model.shells.contains(shell) { shell = model.defaultShell }
            applyModelDefaults()
            game = nil
            graphMode = .view
            screen = model == .evo ? .iconHome : .home
            returnScreen = .home
        }
    }
    /// TI-84 Evo: the entry wiped by CLEAR, restored by 2nd+clear (Undo).
    var undoBuffer: [Character] = []
    /// TI-84 Evo icon home screen selection and Help page.
    var iconIndex = 0
    var helpPage = 0
    /// The app's own home screen, where the calculator is chosen. Shown until one is opened.
    var atHomepage = true

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
        let persisted = VariableStore.persistenceEnabled
        let raw = persisted ? UserDefaults.standard.string(forKey: "shell") ?? "" : ""
        let m = persisted ? CalcModel(rawValue: UserDefaults.standard.string(forKey: "model") ?? "") ?? .ce : .ce
        model = m
        shell = ShellColor(rawValue: raw).flatMap { $0.model == m ? $0 : nil } ?? m.defaultShell
        store.evo = m == .evo
        if m == .evo { screen = .iconHome }
    }

    /// Opens a calculator from the app homepage.
    func open(_ m: CalcModel) {
        if model == m {
            // Already set up (first launch, or coming back to the same one): just show it.
            screen = m == .evo ? .iconHome : .home
            returnScreen = .home
        } else {
            model = m
        }
        atHomepage = false
    }

    /// The TI-84 Evo boots with the decimal window; the CE with the standard one.
    private func applyModelDefaults() {
        let w = GraphWindow(store: store)
        let standard = w.xmin == -10 && w.xmax == 10 && w.ymin == -10 && w.ymax == 10
        let decimal = w.xmin == -6.6 && w.xmax == 6.6 && w.ymin == -4.1 && w.ymax == 4.1
        if model == .evo, standard { Graphing.setWindow(store, -6.6, 6.6, 1, -4.1, 4.1, 1) }
        if model == .ce, decimal { Graphing.setWindow(store, -10, 10, 1, -10, 10, 1) }
    }

    // MARK: - TI-84 Evo toggle key

    /// Continued-fraction approximation with a small denominator, or nil when `x` is not a neat fraction.
    static func rational(_ x: Double, maxDenominator: Int = 10000) -> (Int, Int)? {
        guard x.isFinite, abs(x) < 1e9, x.rounded() != x else { return nil }
        var h0 = 1, h1 = 0, k0 = 0, k1 = 1
        var v = abs(x)
        for _ in 0..<40 {
            let a = Int(v.rounded(.down))
            let h = a * h0 + h1, k = a * k0 + k1
            if k > maxDenominator { break }
            (h1, h0, k1, k0) = (h0, h, k0, k)
            if abs(Double(h0) / Double(k0) - abs(x)) < 1e-10 * max(1, abs(x)) { return (x < 0 ? -h0 : h0, k0) }
            let frac = v - Double(a)
            if frac < 1e-12 { break }
            v = 1 / frac
        }
        return nil
    }

    /// ◂▸ on the home screen: shows the newest answer the other way round (fraction ↔ decimal).
    func toggleLastAnswer() {
        guard let idx = history.lastIndex(where: { $0.trailing && $0.value != nil }), let v = history[idx].value else { return }
        let toggled: Value?
        switch v {
        case .fraction(let n, let d): toggled = .num(Double(n) / Double(d))
        case .num(let x): toggled = Self.rational(x).map { .fraction($0.0, $0.1) }
        default: toggled = nil
        }
        guard let t = toggled else { return }
        let text = ResultFormatter.format(t, store: store, mathPrint: store.mathPrint)
        var line = history[idx]
        line.text = text
        line.value = t
        line.source = text
        line.rows = MathPrint.containsTemplate(text) ? MathLayout.layout(text, width: Self.columns).totalRows : 1
        history[idx] = line
    }

    /// ◂▸ in a menu: the syntax of the highlighted function, as the Evo's toggle-key help.
    func syntaxHelp(for item: MenuItem) -> [String]? {
        guard case .insert(let s) = item.action else { return nil }
        let name = s.hasSuffix("(") ? String(s.dropLast()) : s
        guard let f = Functions.table[name] else { return nil }
        let args: String
        if f.maxArgs > 6 { args = "value1,value2,…" }
        else { args = (0..<f.maxArgs).map { i in i < f.minArgs ? "value\(i + 1)" : "[value\(i + 1)]" }.joined(separator: ",") }
        let count = f.minArgs == f.maxArgs ? "\(f.minArgs)" : (f.maxArgs > 6 ? "\(f.minArgs) or more" : "\(f.minArgs)–\(f.maxArgs)")
        return ["SYNTAX HELP", "", " \(name)(\(args))", "", " \(count) argument" + (count == "1" ? "" : "s"), " [ ] marks optional ones", "", "", "", " Press CLEAR to continue"]
    }

    // MARK: - Home display model

    /// Entry text laid out on the grid (stacked templates in MATHPRINT mode).
    var entryLayout: MathLayout { MathLayout.layout(entry, width: Self.columns) }

    private var historyRows: Int { history.reduce(0) { $0 + $1.rows } }

    private var totalRows: Int { historyRows + entryLayout.totalRows }

    /// Cell row (counting from the top of all history) shown at the top of the screen.
    private var displayStart: Int { max(0, totalRows - Self.visibleRows - homeScroll) }

    /// History lines and the entry, each with its top row on screen; lines partly scrolled off are included.
    var placedLines: [PlacedLine] {
        let start = displayStart
        var out: [PlacedLine] = []
        var row = 0
        for line in history {
            if row + line.rows > start, row < start + Self.visibleRows {
                out.append(PlacedLine(line: line, row: row - start, layout: line.layout))
            }
            row += line.rows
        }
        let el = entryLayout
        out.append(PlacedLine(line: LCDLine(text: String(entry), trailing: false, rows: el.totalRows), row: row - start, layout: el))
        return out
    }

    var displayLines: [LCDLine] { placedLines.map(\.line) }

    /// Cursor position in cells: `row`/`col` are whole cells, `y` adds the half-row offset next to a fraction bar.
    var cursorPosition: (row: Int, col: Int, x: Double, y: Double) {
        let el = entryLayout
        let c = el.cursor(at: cursor)
        let top = historyRows - displayStart + el.rowStart(c.row)
        return (top + Int(c.y), Int(c.x), c.x, Double(top) + c.y)
    }

    var cursorCell: (row: Int, col: Int) { let p = cursorPosition; return (p.row, p.col) }

    // MARK: - History scroll-back (▲/▼ then ENTER pastes)

    /// Moves the highlight to the previous (`step` < 0) or next history item; past the newest it returns to the entry line.
    func selectHistory(step: Int) {
        var groups: [Int] = []
        for l in history where l.source != nil && groups.last != l.group { groups.append(l.group) }
        guard !groups.isEmpty else { return }
        if let sel = historySelection, let i = groups.firstIndex(of: sel) {
            let j = i + (step < 0 ? -1 : 1)
            if j < 0 { return }
            historySelection = j < groups.count ? groups[j] : nil
        } else if step < 0 {
            historySelection = groups.last
        }
        scrollToSelection()
    }

    func clearHistorySelection() {
        historySelection = nil
        homeScroll = 0
    }

    /// Pastes the highlighted history item at the cursor. Returns false if nothing is selected.
    @discardableResult
    func pasteHistorySelection() -> Bool {
        guard let sel = historySelection, let src = history.first(where: { $0.group == sel })?.source else { return false }
        clearHistorySelection()
        guard entry.count + src.count <= Self.columns * 8 else { return true }
        entry.insert(contentsOf: src, at: cursor)
        cursor += src.count
        return true
    }

    /// DEL or CLEAR on a highlighted entry or answer removes that entry/answer pair from the scroll-back;
    /// the highlight moves to the next newer item.
    func deleteHistorySelection() {
        guard let sel = historySelection, let pair = history.first(where: { $0.group == sel })?.pair else { return }
        history.removeAll { $0.pair == pair }
        historySelection = history.first(where: { $0.source != nil && $0.group > sel })?.group
        store.ans = history.last(where: { $0.value != nil })?.value ?? .num(0)   // Ans follows what is still on screen
        scrollToSelection()
    }

    private func scrollToSelection() {
        guard let sel = historySelection else { homeScroll = 0; return }
        var first: Int? = nil, last = 0
        var row = 0
        for l in history {
            if l.group == sel { if first == nil { first = row }; last = row + l.rows - 1 }
            row += l.rows
        }
        guard let first else { homeScroll = 0; return }
        var start = displayStart
        if first < start { start = first }
        else if last >= start + Self.visibleRows { start = last - Self.visibleRows + 1 }
        homeScroll = max(0, totalRows - Self.visibleRows - start)
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

    // The entry line is edited in display tokens: "sin(", "√(", "L₁", "⁻¹" … each count as one
    // unit for the cursor, DEL and overwrite, as on the real calculator.

    func insert(_ s: String) {
        guard entry.count + s.count <= Self.columns * 8 else { return }
        // The Evo's bar cursor never overwrites; the CE overwrites the token under the cursor unless INS is on.
        if !insertMode, !store.evo, cursor < entry.count, !MathPrint.isTemplate(entry[cursor]) {
            let r = Tokenizer.displayTokenRange(in: entry, containing: cursor)
            entry.removeSubrange(r)
            cursor = r.lowerBound
        }
        let at = cursor
        entry.insert(contentsOf: s, at: at)
        if let k = s.firstIndex(where: { MathPrint.isOpen($0) || $0 == MathPrint.mixedOpen }) {
            // A freshly inserted template opens with the cursor in its first empty slot.
            cursor = MathPrint.firstEmptySlot(in: entry, from: at + s.distance(from: s.startIndex, to: k))
        } else {
            cursor += s.count
        }
    }

    /// In MATHPRINT mode the home screen swaps flat tokens (^, √(, Σ( …) for their stacked templates.
    func mathPrintToken(_ s: String) -> String {
        guard store.mathPrint, !hardwareTyping else { return s }
        // The Evo's log key is the log-of-any-base template (an empty base means 10).
        if store.evo, s == "log(" { return MathPrint.template(.logBase) }
        return MathPrint.template(for: s)
    }

    func deleteAtCursor() {
        if entry.isEmpty { return }
        let pos = cursor < entry.count ? cursor : entry.count - 1
        let r = MathPrint.templateRange(in: entry, containing: pos) ?? Tokenizer.displayTokenRange(in: entry, containing: pos)
        entry.removeSubrange(r)
        cursor = r.lowerBound
    }

    func moveCursorLeft() {
        guard cursor > 0 else { return }
        cursor = Tokenizer.displayTokenRange(in: entry, containing: min(cursor, entry.count) - 1).lowerBound
    }

    func moveCursorRight() {
        guard cursor < entry.count else { return }
        cursor = Tokenizer.displayTokenRange(in: entry, containing: cursor).upperBound
    }

    func appendHistory(expr: String, result: String, value: Value? = nil) {
        let exprGroup = nextGroup, resultGroup = nextGroup + 1
        nextGroup += 2
        if MathPrint.containsTemplate(expr) {
            // Stacked templates wrap inside their layout, so the whole entry is one (taller) line.
            history.append(LCDLine(text: expr, trailing: false, source: expr, group: exprGroup, pair: exprGroup, rows: MathLayout.layout(expr, width: Self.columns).totalRows))
        } else {
            for c in Self.chunk(expr, Self.columns) {
                history.append(LCDLine(text: c, trailing: false, source: expr, group: exprGroup, pair: exprGroup))
            }
        }
        let resultLines = result.split(separator: "\n", omittingEmptySubsequences: false)
        let pasteable = resultLines.count == 1 ? result : nil   // multi-line answers (matrices) can't be re-entered as text
        for line in resultLines {
            let text = String(line)
            let rows = MathPrint.containsTemplate(text) ? MathLayout.layout(text, width: Self.columns).totalRows : 1
            history.append(LCDLine(text: text, trailing: true, source: pasteable, group: resultGroup, pair: exprGroup, value: value, rows: rows))
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
        clearHistorySelection()
        if ProgramRunner.isStatement(text) {
            for c in Self.chunk(text, Self.columns) { history.append(LCDLine(text: c, trailing: false)) }
            entry = []
            cursor = 0
            runProgram(lines: [text])
            return
        }
        do {
            let v = store.answerForm(try Evaluator.evaluate(text, ctx: EvalContext(store: store)), entryUsedFraction: text.contains(MathPrint.fracOpen))
            if case .str(let s) = v, s == "Done" {} else { store.ans = v }
            appendHistory(expr: text, result: ResultFormatter.format(v, store: store, mathPrint: store.mathPrint), value: v)
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
        let prod = model == .evo ? "0E-84-EV-0001" : "0E-84-CE-0003"
        return ["", "      \(model.brand) v\(Self.version)", "", "  \(model.fullName) replica", "  PROD#: \(prod)", "  ID: 84LT-0R00-0003", "", "  RAM FREE \(MemoryModel.ramFree(store))", "  ARC FREE \(MemoryModel.arcFreeText(store))", "  Not affiliated with TI"]
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
