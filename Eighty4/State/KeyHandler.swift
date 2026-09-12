import Foundation

extension CalculatorState {
    // MARK: - Entry point

    func press(_ key: KeyID) {
        defer { store.save() }

        if screen == .off {
            if key == .on { screen = model == .evo ? .iconHome : .home; modifier = .none }
            return
        }
        if key == .second {
            modifier = (modifier == .second) ? .none : .second
            return
        }
        if key == .alpha {
            switch modifier {
            case .second: modifier = .alphaLock
            case .alpha, .alphaLock: modifier = .none
            case .none: modifier = .alpha
            }
            return
        }

        let mod = modifier
        if mod != .alphaLock { modifier = .none }

        if case .error = screen {
            if key == .two, let (name, line) = errorGoto, store.programs[name] != nil, !store.lockedPrograms.contains(name) {
                errorGoto = nil
                openProgramEditor(name, line: max(0, line))
                return
            }
            errorGoto = nil
            screen = returnScreen
            returnScreen = .home
            return
        }
        if runner != nil { handleRunner(key, mod); return }
        if mod == .second && key == .on { turnOff(); return }
        if mod == .second && key == .mode { quitToHome(); return }
        if model == .evo && key == .on { pressHome(); return }

        switch screen {
        case .home: handleHome(key, mod)
        case .iconHome: handleIconHome(key, mod)
        case .help(let page): handleHelp(page, key, mod)
        case .menu(let id): handleMenu(id, key, mod)
        case .editor(let id): handleEditor(id, key, mod)
        case .yEquals: handleYEquals(key, mod)
        case .listEditor: handleListEditor(key, mod)
        case .matrixEditor: handleMatrixEditor(key, mod)
        case .graph: handleGraph(key, mod)
        case .table: handleTable(key, mod)
        case .app: handleApp(key, mod)
        case .solver: handleSolver(key, mod)
        case .varList(let m): handleVarList(m, key, mod)
        case .confirm(let c): handleConfirm(c, key)
        case .programEditor: handleProgramEditor(key, mod)
        case .programName, .groupName: handleNameEntry(key, mod)
        case .programMenu(_, let items): handleProgramMenu(items, key)
        case .linkReceive:
            screen = .error("ERR:Error in Xmit")
            returnScreen = .home
        case .message, .about:
            if key == .clear || key == .enter { screen = returnScreen; returnScreen = .home }
            else { _ = routeNavigation(resolve(key, mod)) }
        case .off, .error: break
        }
    }

    // MARK: - Key resolution

    private func alphaCharacter(_ label: String) -> String? {
        if label == "␣" { return " " }
        if label.count == 1 { return label }
        return nil
    }

    func resolve(_ key: KeyID, _ mod: Modifier) -> KeyAction {
        if mod == .alpha || mod == .alphaLock {
            // alpha + f1…f4 open the FRAC / FUNC / MTRX / YVAR shortcut menus.
            if let n = [KeyID.yEquals, .window, .zoom, .trace].firstIndex(of: key) { return .openMenu(.shortcut(n + 1)) }
            if model == .evo, key == .stat { return .openMenu(.distr) }
            if let a = Keymap.spec(key, model: model)?.alpha, let ch = alphaCharacter(a) { return .insert(ch) }
        }
        if mod == .second { return secondAction(key) }
        return primaryAction(key)
    }

    private func primaryAction(_ key: KeyID) -> KeyAction {
        switch key {
        case .zero: return .insert("0")
        case .one: return .insert("1")
        case .two: return .insert("2")
        case .three: return .insert("3")
        case .four: return .insert("4")
        case .five: return .insert("5")
        case .six: return .insert("6")
        case .seven: return .insert("7")
        case .eight: return .insert("8")
        case .nine: return .insert("9")
        case .dot: return .insert(".")
        case .negate: return .insert("⁻")
        case .plus: return .insert("+")
        case .minus: return .insert("−")
        case .multiply: return .insert(model == .evo ? "⋅" : "×")   // the Evo shows a dot for multiplication
        case .divide: return .insert("÷")
        case .power: return .insert("^")
        // TI-84 Evo keys: n/d template, x^□ exponent template, ◂▸ toggle.
        case .fraction: return .insert("/")
        case .expTemplate: return .insert("^")
        case .toggle: return .toggle
        case .square: return .insert("²")
        case .inverse: return .insert("⁻¹")
        case .lparen: return .insert("(")
        case .rparen: return .insert(")")
        case .comma: return .insert(",")
        case .xtn: return .insert(Graphing.parameterName(store))
        case .sin: return .insert("sin(")
        case .cos: return .insert("cos(")
        case .tan: return .insert("tan(")
        case .log: return .insert("log(")
        case .ln: return .insert("ln(")
        case .sto: return .insert("→")
        case .enter: return .enter
        case .clear: return .clear
        case .del: return .del
        case .left: return .left
        case .right: return .right
        case .up: return .up
        case .down: return .down
        case .on: return .on
        case .yEquals: return .openYEquals
        case .window: return .openEditor(.window)
        case .zoom: return .openMenu(.zoom)
        case .trace: return .openTrace
        case .graph: return .openGraph
        case .mode: return .openEditor(.mode)
        case .stat: return .openMenu(.stat)
        case .math: return .openMenu(.math)
        case .apps: return .openMenu(.apps)
        case .prgm: return .openMenu(.prgm)
        case .vars: return .openMenu(.vars)
        case .second, .alpha: return .none
        }
    }

    private func secondAction(_ key: KeyID) -> KeyAction {
        let sub = Tokenizer.subscripts
        switch key {
        case .yEquals: return .openMenu(.statPlot)
        case .window: return .openEditor(.tblset)
        case .zoom: return .openEditor(.format)
        case .trace: return .openMenu(.calc)
        case .graph: return .openTable
        case .del: return .ins
        case .xtn: return .openMenu(.link)
        case .stat: return .openMenu(.list)
        case .math: return .openMenu(.test)
        case .apps: return .openMenu(.angle)
        case .prgm: return .openMenu(.draw)
        case .vars: return model == .evo ? .openMenu(.matrix) : .openMenu(.distr)
        case .inverse: return .openMenu(.matrix)
        case .left: return model == .evo ? .lineStart : primaryAction(key)
        case .right: return model == .evo ? .lineEnd : primaryAction(key)
        case .up, .down: return model == .evo ? .none : primaryAction(key)   // 2nd+▲/▼ dim and brighten the screen
        // TI-84 Evo: the 2nd legends keep their positions, so the shifted operator keys carry π e [ ] MEM.
        case .fraction: return .openMenu(.angle)
        case .expTemplate: return .insert("ˣ√")
        case .toggle: return .openMenu(.mem)
        case .clear: return model == .evo ? .undo : primaryAction(key)
        case .sin: return .insert("sin⁻¹(")
        case .cos: return .insert("cos⁻¹(")
        case .tan: return .insert("tan⁻¹(")
        case .power: return .insert("π")
        case .square: return .insert("√(")
        case .comma: return .insert("ᴇ")
        case .lparen: return .insert("{")
        case .rparen: return .insert("}")
        case .divide: return .insert(model == .evo ? "π" : "e")
        case .log: return .insert("10^(")
        case .ln: return .insert("e^(")
        case .multiply: return .insert(model == .evo ? "e" : "[")
        case .minus: return .insert(model == .evo ? "[" : "]")
        case .seven: return .insert("u")
        case .eight: return .insert("v")
        case .nine: return .insert("w")
        case .one: return .insert("L\(sub[1])")
        case .two: return .insert("L\(sub[2])")
        case .three: return .insert("L\(sub[3])")
        case .four: return .insert("L\(sub[4])")
        case .five: return .insert("L\(sub[5])")
        case .six: return .insert("L\(sub[6])")
        case .sto: return .rcl
        case .plus: return model == .evo ? .insert("]") : .openMenu(.mem)
        case .zero: return .openMenu(.catalog)
        case .dot: return .insert("i")
        case .negate: return .insert("Ans")
        case .enter: return .entry
        default: return primaryAction(key)
        }
    }

    /// Navigation shared by every non-menu screen. Returns true if handled.
    @discardableResult
    func routeNavigation(_ action: KeyAction) -> Bool {
        switch action {
        case .openMenu(let id):
            let from: Screen = (screen == .yEquals || screen == .solver) ? screen : (isProgramEditor ? screen : .home)
            leaveEditorsIfNeeded(keepY: true)
            openMenu(id, from: from)
        case .openEditor(let id):
            leaveEditorsIfNeeded(keepY: false)
            openEditor(id)
        case .openYEquals:
            leaveEditorsIfNeeded(keepY: true)
            if screen != .yEquals { enterYEquals() }
        case .openGraph:
            leaveEditorsIfNeeded(keepY: false)
            openGraph(.view)
        case .openTrace:
            leaveEditorsIfNeeded(keepY: false)
            openGraph(.trace)
        case .openTable:
            leaveEditorsIfNeeded(keepY: false)
            openTable()
        default:
            return false
        }
        return true
    }

    private var isProgramEditor: Bool { if case .programEditor = screen { return true }; return false }

    private func leaveEditorsIfNeeded(keepY: Bool) {
        switch screen {
        case .yEquals: if !keepY { leaveYEquals() } else { commitYRow() }
        case .editor: commitEditorNumber()
        case .listEditor: commitListCell()
        case .matrixEditor: commitMatrixCell()
        case .programEditor: commitProgramLine(); entry = homeEntryBackup; cursor = min(homeCursorBackup, entry.count)
        case .solver: commitSolverValue(); if solverStage == 0 { store.solverEqn = String(entry) }; entry = homeEntryBackup; cursor = min(homeCursorBackup, entry.count)
        default: break
        }
    }

    // MARK: - Screen transitions

    private func turnOff() {
        leaveEditorsIfNeeded(keepY: false)
        game = nil
        screen = .off
        returnScreen = .home
    }

    func quitToHome() {
        leaveEditorsIfNeeded(keepY: false)
        game = nil
        graphMode = .view
        screen = .home
        returnScreen = .home
    }

    // MARK: - TI-84 Evo home key, icon screen and Help

    /// The home key shows the icon screen; pressed there it drops into the Calculator app.
    func pressHome() {
        if screen == .iconHome { screen = .home; returnScreen = .home; return }
        leaveEditorsIfNeeded(keepY: false)
        game = nil
        graphMode = .view
        screen = .iconHome
        returnScreen = .home
    }

    private func handleIconHome(_ key: KeyID, _ mod: Modifier) {
        let cols = HomeIcon.columns, count = HomeIcon.allCases.count
        switch key {
        case .left: iconIndex = (iconIndex - 1 + count) % count
        case .right: iconIndex = (iconIndex + 1) % count
        case .up: if iconIndex - cols >= 0 { iconIndex -= cols }
        case .down: if iconIndex + cols < count { iconIndex += cols }
        case .enter: openIcon(HomeIcon.allCases[iconIndex])
        case .toggle: helpPage = 0; screen = .help(0)
        case .clear: screen = .home
        default:
            // Typing on the icon screen goes straight into the Calculator app, as on the Evo.
            let action = resolve(key, mod)
            switch action {
            case .insert: screen = .home; handleHome(key, mod)
            default: _ = routeNavigation(action)
            }
        }
    }

    func openIcon(_ icon: HomeIcon) {
        screen = .home
        returnScreen = .home
        switch icon {
        case .calculator: break
        case .functionEditor: enterYEquals()
        case .listEditor: runCommand(.listEditor)
        case .mode: openEditor(.mode)
        case .numericSolver: openSolver()
        case .polyRootFinder, .systemSolver: startApp(.plySmlt2)
        case .finance: openEditor(.tvm)
        case .transformation: startApp(.transfrm)
        case .inequality: startApp(.inequalz)
        case .linesConics: startApp(.conics)
        case .python: startApp(.python)
        case .tiBasic: openMenu(.prgm, from: .home)
        case .help: helpPage = 0; screen = .help(0)
        }
    }

    private func handleHelp(_ page: Int, _ key: KeyID, _ mod: Modifier) {
        let n = HelpPages.pages.count
        switch key {
        case .right, .down, .enter: helpPage = (page + 1) % n; screen = .help(helpPage)
        case .left, .up: helpPage = (page - 1 + n) % n; screen = .help(helpPage)
        case .clear: screen = .home
        case .toggle: screen = .iconHome
        default: break
        }
    }

    func openMenu(_ id: MenuID, from: Screen) {
        if case .menu = screen {} else { returnScreen = from }
        menuTab = 0
        menuRow = 0
        screen = .menu(id)
    }

    func openEditor(_ id: EditorID) {
        editorRow = 0
        editorBuffer = []
        editorTyping = false
        tvmSolved = nil
        screen = .editor(id)
        syncEditorCol(id)
        returnScreen = .home
    }

    private func syncEditorCol(_ id: EditorID) {
        let def = Editors.def(id, store: store)
        guard editorRow < def.rows.count else { return }
        if case .options(let r) = def.rows[editorRow] { editorCol = store.options[r.key] ?? 0 } else { editorCol = 0 }
    }

    func enterYEquals() {
        if screen == .home {
            homeEntryBackup = entry
            homeCursorBackup = cursor
        }
        yRow = min(yRow, yKeys.count - 1)
        loadYRow()
        screen = .yEquals
        returnScreen = .yEquals
    }

    private func leaveYEquals() {
        commitYRow()
        entry = homeEntryBackup
        cursor = min(homeCursorBackup, entry.count)
        returnScreen = .home
    }

    func loadYRow() {
        let key = yKeys[min(yRow, yKeys.count - 1)]
        if key == "nMin" { entry = Array(ResultFormatter.number(store.numbers["nMin"] ?? 1)) }
        else { entry = Array(store.funcText(key) ?? "") }
        cursor = entry.count
    }

    func commitYRow() {
        let key = yKeys[min(yRow, yKeys.count - 1)]
        let text = String(entry)
        if key == "nMin" {
            if let v = try? Evaluator.number(text, ctx: EvalContext(store: store)) { store.numbers["nMin"] = v; store.seqCache = [:] }
        } else {
            store.setFuncText(key, text)
        }
    }

    func openGraph(_ mode: GraphMode) {
        let w = GraphWindow(store: store)
        guard w.isValid else { fail(.windowRange); return }
        store.seqCache = [:]
        graphSamples = Graphing.samples(store)
        let defined = Graphing.definedFunctions(store)
        if !defined.contains(traceFn) { traceFn = defined.first ?? 1 }
        let (pmin, pmax, _) = Graphing.parameterRange(store)
        traceX = store.graphType == .function ? (w.xmin + w.xmax) / 2 : pmin
        if store.graphType == .sequence { traceX = pmin }
        _ = pmax
        cursorY = (w.ymin + w.ymax) / 2
        zboxFirst = nil
        penDown = false
        calcStage = 0
        calcBounds = []
        calcFns = []
        calcResult = nil
        graphBuffer = []
        graphMode = mode
        if case .trace = mode, defined.isEmpty { graphMode = .view }
        screen = .graph
        returnScreen = .home
    }

    func openTable() {
        tableStart = store.numbers["TblStart"] ?? 0
        if store.graphType == .sequence { tableStart = store.numbers["nMin"] ?? 1 }
        tableRow = 0
        tableCol = 0
        screen = .table
        returnScreen = .home
    }

    func startApp(_ id: AppID) {
        switch id {
        case .geoDash: game = GeoDashGame()
        case .tetris: game = TetrisGame()
        case .plySmlt2: game = PlySmlt2App(store: store)
        case .conics: game = ConicsApp(store: store)
        case .inequalz: game = InequalzApp(store: store)
        case .probSim: game = ProbSimApp()
        case .sciTools: game = SciToolsApp(store: store)
        case .transfrm: game = TransfrmApp(store: store)
        case .celSheet: game = CelSheetApp(store: store)
        case .cabriJr: game = CabriJrApp()
        case .vernier: game = VernierApp()
        case .python: game = PythonApp(store: store)
        }
        screen = .app(id)
        returnScreen = .home
    }

    func openProgramEditor(_ name: String, line: Int = 0) {
        programName = name
        programLines = store.programs[name] ?? [""]
        if programLines.isEmpty { programLines = [""] }
        programRow = min(line, programLines.count - 1)
        homeEntryBackup = entry
        homeCursorBackup = cursor
        entry = Array(programLines[programRow])
        cursor = entry.count
        screen = .programEditor(name)
        returnScreen = .home
    }

    // MARK: - Home

    private func handleHome(_ key: KeyID, _ mod: Modifier) {
        let action = resolve(key, mod)
        if rclPending {
            rclPending = false
            if case .insert(let s) = action, let tokens = try? Tokenizer.tokenize(s), tokens.count == 1,
               let v = try? Evaluator.evaluate(s, ctx: EvalContext(store: store)) {
                insert(ResultFormatter.format(v, store: store))
            }
            return
        }
        if historySelection != nil {
            // ▲/▼ walk the scroll-back, ENTER pastes, DEL/CLEAR remove the entry+answer pair; anything else drops the highlight first.
            switch action {
            case .up: selectHistory(step: -1); return
            case .down: selectHistory(step: 1); return
            case .enter: pasteHistorySelection(); return
            case .del, .clear: deleteHistorySelection(); return
            default: clearHistorySelection()
            }
        }
        if routeNavigation(action) { return }
        switch action {
        case .insert(let s): historyIndex = nil; insert(mathPrintToken(s))
        case .enter: evaluate()
        case .entry:
            if entry.isEmpty, let last = store.entries.last { entry = Array(last); cursor = entry.count }
            else { evaluate() }
        case .clear:
            // Clearing the screen also forgets Ans, so a fresh screen really starts from 0.
            if entry.isEmpty { history = []; store.ans = .num(0) } else { undoBuffer = entry; entry = []; cursor = 0 }
            historyIndex = nil
        case .undo:
            // TI-84 Evo 2nd+clear: the last cleared entry comes back at the cursor.
            if !undoBuffer.isEmpty { insert(String(undoBuffer)) }
        case .toggle: toggleLastAnswer()
        case .del: deleteAtCursor()
        case .ins: insertMode.toggle()
        case .left: moveCursorLeft()
        case .right: moveCursorRight()
        case .lineStart: cursor = 0
        case .lineEnd: cursor = entry.count
        case .up: selectHistory(step: -1)
        case .down: break
        case .rcl: rclPending = true
        default: break
        }
    }

    private func recallEntry(step: Int) {
        let entries = store.entries
        guard !entries.isEmpty else { return }
        var idx = (historyIndex ?? entries.count) + step
        if idx < 0 { idx = 0 }
        if idx >= entries.count {
            historyIndex = nil
            entry = []
            cursor = 0
            return
        }
        historyIndex = idx
        entry = Array(entries[idx])
        cursor = entry.count
    }

    // MARK: - Running programs

    private func handleRunner(_ key: KeyID, _ mod: Modifier) {
        guard let r = runner else { return }
        if key == .on { breakProgram(); return }
        switch r.wait {
        case .input:
            let action = resolve(key, mod)
            switch action {
            case .insert(let s): insert(s)
            case .del: deleteAtCursor()
            case .ins: insertMode.toggle()
            case .left: moveCursorLeft()
            case .right: moveCursorRight()
            case .clear: entry = []; cursor = 0
            case .enter, .entry:
                let text = String(entry)
                if let last = history.indices.last { history[last] = LCDLine(text: String((history[last].text + text).prefix(Self.columns)), trailing: false) }
                entry = []; cursor = 0
                resumeRunner(input: text)
            default: break
            }
        case .enter:
            if key == .enter { resumeRunner(input: nil) }
        case .key:
            store.lastKey = mod == .second ? 21 : KeyCodes.code(key)
            resumeRunner(input: nil)
        case .menu(_, let items, _):
            handleProgramMenu(items, key)
        case .none:
            break
        }
    }

    private func handleProgramMenu(_ items: [String], _ key: KeyID) {
        switch key {
        case .up: programMenuRow = (programMenuRow - 1 + items.count) % max(1, items.count)
        case .down: programMenuRow = (programMenuRow + 1) % max(1, items.count)
        case .enter:
            screen = .home
            resumeRunner(input: String(programMenuRow + 1))
        case .clear:
            breakProgram()
        default:
            if case .insert(let s) = resolve(key, .none), let d = Int(s), d >= 1, d <= items.count {
                screen = .home
                resumeRunner(input: String(d))
            }
        }
    }

    // MARK: - Menus

    private func handleMenu(_ id: MenuID, _ key: KeyID, _ mod: Modifier) {
        let def = Menus.def(id, store: store)
        let tabCount = def.tabs.count
        menuTab = min(menuTab, tabCount - 1)
        let items = def.tabs[menuTab].items
        switch key {
        case .left: menuTab = (menuTab - 1 + tabCount) % tabCount; menuRow = 0
        case .right: menuTab = (menuTab + 1) % tabCount; menuRow = 0
        case .up: menuRow = (menuRow - 1 + items.count) % max(1, items.count)
        case .down: menuRow = (menuRow + 1) % max(1, items.count)
        case .clear: closeMenu()
        case .enter:
            if menuRow < items.count { select(items[menuRow]) }
        case .toggle:
            // TI-84 Evo ◂▸ in a menu: syntax help for the highlighted function; CLEAR comes back to the menu.
            if menuRow < items.count, let help = syntaxHelp(for: items[menuRow]) {
                let back = screen
                screen = .message(help)
                returnScreen = back
            }
        default:
            if id == .catalog, let a = Keymap.spec(key, model: model)?.alpha, let ch = alphaCharacter(a), ch != " " {
                if let idx = items.firstIndex(where: { $0.label.lowercased().hasPrefix(ch.lowercased()) }) { menuRow = idx }
                return
            }
            if case .insert(let s) = resolve(key, .none), s.count == 1, let d = Int(s) {
                let idx = d == 0 ? 9 : d - 1
                if idx < items.count { select(items[idx]) }
                return
            }
            // Graph/menu keys pressed inside a menu open the new screen.
            let action = resolve(key, mod)
            if case .openMenu(let other) = action { openMenu(other, from: returnScreen); return }
            screen = returnScreen
            if routeNavigation(action) { return }
        }
    }

    private func closeMenu() {
        screen = returnScreen
        if screen == .yEquals { returnScreen = .yEquals }
        else if case .programEditor = screen {}
        else { returnScreen = .home }
    }

    private func select(_ item: MenuItem) {
        switch item.action {
        case .insert(let s):
            closeMenu()
            // Stacked templates only render on the home screen; other editors get the flat form.
            if screen == .home { insert(mathPrintToken(s)) }
            else if screen == .solver, solverStage == 1 {
                if !editorTyping { editorBuffer = []; editorTyping = true }
                editorBuffer += Array(MathPrint.classicInsert(s))
            }
            else if screen == .yEquals || screen == .solver || isProgramEditor { insert(MathPrint.classicInsert(s)) }
            else { screen = .home; insert(mathPrintToken(s)) }
        case .submenu(let id):
            menuTab = 0; menuRow = 0
            screen = .menu(id)
        case .editor(let id):
            leaveForCommand()
            openEditor(id)
        case .app(let id):
            leaveForCommand()
            startApp(id)
        case .command(let c):
            runCommand(c)
        }
    }

    /// Leaves the Y= / program editor cleanly before a command switches screens.
    private func leaveForCommand() {
        if returnScreen == .yEquals { leaveYEquals() }
        if case .programEditor = returnScreen { commitProgramLine(); entry = homeEntryBackup; cursor = min(homeCursorBackup, entry.count); returnScreen = .home }
    }

    private func showMessage(_ lines: [String]) {
        leaveForCommand()
        screen = .message(lines)
        returnScreen = .home
    }

    private func runCommand(_ c: Command) {
        switch c {
        case .zoom(let kind):
            leaveForCommand()
            let center: (Double, Double)? = (screen == .graph || returnScreen == .graph) ? (traceX, Graphing.y(traceFn, at: traceX, store: store) ?? 0) : nil
            Graphing.zoom(kind, store: store, center: center)
            openGraph(.view)
        case .zbox:
            leaveForCommand()
            openGraph(.zbox)
        case .pen:
            leaveForCommand()
            openGraph(.pen)
        case .clearEntries:
            store.entries = []
            closeMenu(); screen = .home
            appendHistory(expr: "Clear Entries", result: "Done")
        case .about:
            leaveForCommand()
            screen = .about; returnScreen = .home
        case .oneVar, .twoVar, .linReg, .linRegAlt, .quadReg, .cubicReg, .quartReg, .expReg, .lnReg, .pwrReg, .medMed, .logistic, .sinReg,
             .propReg, .recipReg, .eBaseReg:
            runStatCalc(c)
        case .listEditor:
            leaveForCommand()
            listRow = 0; listCol = 0
            editorBuffer = []; editorTyping = false
            screen = .listEditor; returnScreen = .home
        case .matrixEdit(let name):
            leaveForCommand()
            matName = name
            if store.matrices[name] == nil { store.matrices[name] = [[0]] }
            matRow = -1; matCol = 0
            editorBuffer = []; editorTyping = false
            screen = .matrixEditor(name); returnScreen = .home
        case .calc(let op):
            leaveForCommand()
            guard !Graphing.definedFunctions(store).isEmpty else { fail(.undefined); returnScreen = .home; return }
            openGraph(.calc(op))
        case .trace:
            openGraph(.trace)
        case .linkSend:
            showMessage(["", "", "  Nothing to send.", "", "  Error in Xmit", "", "", "", "", "  Press CLEAR to continue"])
        case .linkReceive:
            screen = .linkReceive; returnScreen = .home
        case .clrDraw:
            store.drawings = []
            closeMenu(); screen = .home
            appendHistory(expr: "ClrDraw", result: "Done")
        case .insertRegEQ:
            closeMenu()
            if screen != .home && screen != .yEquals { screen = .home }
            insert(store.regEQ.isEmpty ? "0" : store.regEQ)
        case .solver:
            leaveForCommand()
            openSolver()
        case .statTest(let t):
            leaveForCommand()
            openEditor(.statTest(t))
        case .runProgram(let name):
            leaveForCommand()
            screen = .home; returnScreen = .home
            entry = []; cursor = 0
            insert("prgm" + name)
            evaluate()
        case .editProgram(let name):
            leaveForCommand()
            if store.lockedPrograms.contains(name) { screen = .confirm(.programUnlock(name)); returnScreen = .home }
            else { openProgramEditor(name) }
        case .newProgram:
            leaveForCommand()
            nameBuffer = []
            modifier = .alphaLock
            screen = .programName; returnScreen = .home
        case .varList(let mode):
            leaveForCommand()
            varListRow = 0
            screen = .varList(mode); returnScreen = .home
        case .confirm(let kind):
            leaveForCommand()
            screen = .confirm(kind); returnScreen = .home
        case .createGroup:
            leaveForCommand()
            nameBuffer = []
            modifier = .alphaLock
            screen = .groupName; returnScreen = .home
        case .ungroup(let name):
            if let g = store.groups[name] { store.ungroup(g) }
            showMessage(["", "", "  Ungrouped \(name)", "", "", "", "", "", "", "  Press CLEAR to continue"])
        }
    }

    private func runStatCalc(_ c: Command) {
        let x = store.lists["L1"] ?? [], y = store.lists["L2"] ?? []
        func fmt(_ v: Double) -> String { ResultFormatter.format(.num(v), store: store) }
        do {
            var lines: [String] = []
            var pairs: [(String, Double)] = []
            switch c {
            case .oneVar:
                lines.append("1-Var Stats")
                pairs = try Stats.oneVar(x)
            case .twoVar:
                lines.append("2-Var Stats")
                pairs = try Stats.twoVar(x, y)
            case .linReg, .medMed:
                let r = try Stats.linReg(x, y)
                lines.append(c == .medMed ? "Med-Med" : "LinReg")
                lines.append(" y=ax+b")
                pairs = [("a", r.a), ("b", r.b), ("r²", r.r * r.r), ("r", r.r)]
                store.regEQ = "\(fmt(r.a))X+\(fmt(r.b))"
            case .linRegAlt:
                let r = try Stats.linReg(x, y)
                lines.append("LinReg"); lines.append(" y=a+bx")
                pairs = [("a", r.b), ("b", r.a), ("r²", r.r * r.r), ("r", r.r)]
                store.regEQ = "\(fmt(r.b))+\(fmt(r.a))X"
            case .quadReg, .cubicReg, .quartReg:
                let degree = c == .quadReg ? 2 : (c == .cubicReg ? 3 : 4)
                let coef = try Stats.polyReg(x, y, degree: degree)
                lines.append(c == .quadReg ? "QuadReg" : (c == .cubicReg ? "CubicReg" : "QuartReg"))
                lines.append(degree == 2 ? " y=ax²+bx+c" : (degree == 3 ? " y=ax³+bx²+cx+d" : " y=ax⁴+…+e"))
                let names = ["a", "b", "c", "d", "e"]
                pairs = zip(names, coef).map { ($0, $1) }
                var eq = ""
                for (i, k) in coef.enumerated() {
                    let p = degree - i
                    eq += (i > 0 && k >= 0 ? "+" : "") + fmt(k) + (p == 0 ? "" : (p == 1 ? "X" : "X^\(p)"))
                }
                store.regEQ = eq
            case .expReg:
                guard y.allSatisfy({ $0 > 0 }) else { throw CalcError.domain }
                let r = try Stats.linReg(x, y.map { log($0) })
                lines.append("ExpReg"); lines.append(" y=a*b^x")
                let a = exp(r.b), b = exp(r.a)
                pairs = [("a", a), ("b", b), ("r²", r.r * r.r), ("r", r.r)]
                store.regEQ = "\(fmt(a))×\(fmt(b))^X"
            case .lnReg:
                guard x.allSatisfy({ $0 > 0 }) else { throw CalcError.domain }
                let r = try Stats.linReg(x.map { log($0) }, y)
                lines.append("LnReg"); lines.append(" y=a+blnx")
                pairs = [("a", r.b), ("b", r.a), ("r²", r.r * r.r), ("r", r.r)]
                store.regEQ = "\(fmt(r.b))+\(fmt(r.a))ln(X)"
            case .pwrReg:
                guard x.allSatisfy({ $0 > 0 }), y.allSatisfy({ $0 > 0 }) else { throw CalcError.domain }
                let r = try Stats.linReg(x.map { log($0) }, y.map { log($0) })
                lines.append("PwrReg"); lines.append(" y=a*x^b")
                let a = exp(r.b)
                pairs = [("a", a), ("b", r.a), ("r²", r.r * r.r), ("r", r.r)]
                store.regEQ = "\(fmt(a))×X^\(fmt(r.a))"
            case .logistic:
                let r = try Stats.logisticReg(x, y)
                lines.append("Logistic"); lines.append(" y=c/(1+ae^(-bx))")
                pairs = [("a", r.a), ("b", r.b), ("c", r.c)]
                store.regEQ = "\(fmt(r.c))÷(1+\(fmt(r.a))e^(⁻\(fmt(r.b))X))"
            case .sinReg:
                let r = try Stats.sinReg(x, y)
                lines.append("SinReg"); lines.append(" y=a*sin(bx+c)+d")
                pairs = [("a", r.a), ("b", r.b), ("c", r.c), ("d", r.d)]
                store.regEQ = "\(fmt(r.a))sin(\(fmt(r.b))X+\(fmt(r.c)))+\(fmt(r.d))"
            case .propReg:
                // Least squares through the origin: a = Σxy / Σx².
                guard x.count == y.count, !x.isEmpty else { throw CalcError.dimMismatch }
                let sxx = x.reduce(0) { $0 + $1 * $1 }, sxy = zip(x, y).reduce(0) { $0 + $1.0 * $1.1 }
                guard sxx > 0 else { throw CalcError.domain }
                let a = sxy / sxx
                lines.append("PropReg"); lines.append(" y=ax")
                pairs = [("a", a)]
                store.regEQ = "\(fmt(a))X"
            case .recipReg:
                let r = try Stats.linReg(x.map { 1 / $0 }, y)
                lines.append("RecipReg"); lines.append(" y=a+b/x")
                pairs = [("a", r.b), ("b", r.a), ("r²", r.r * r.r), ("r", r.r)]
                store.regEQ = "\(fmt(r.b))+\(fmt(r.a))÷X"
            case .eBaseReg:
                let r = try Stats.linReg(x, y.map { log($0) })
                lines.append("eBASEReg"); lines.append(" y=ae^(bx)")
                let a = exp(r.b)
                pairs = [("a", a), ("b", r.a), ("r²", r.r * r.r), ("r", r.r)]
                store.regEQ = "\(fmt(a))e^(\(fmt(r.a))X)"
            default:
                return
            }
            for (k, v) in pairs {
                store.stats[k] = v
                lines.append(" \(k)=\(fmt(v))")
            }
            leaveForCommand()
            screen = .message(Array(lines.prefix(10)))
            returnScreen = .home
        } catch let e as CalcError {
            returnScreen = .home
            screen = .error(e.message)
        } catch {
            returnScreen = .home
            screen = .error("ERR:SYNTAX")
        }
    }

    // MARK: - Settings / number editors

    private func handleEditor(_ id: EditorID, _ key: KeyID, _ mod: Modifier) {
        let def = Editors.def(id, store: store)
        editorRow = min(editorRow, def.rows.count - 1)
        let row = def.rows[editorRow]
        let isNumber: Bool = { if case .number = row { return true }; return false }()

        if id == .tvm, key == .enter, mod == .alpha || mod == .alphaLock, case .number(let k, _) = row {
            commitEditorNumber()
            do {
                let v = try Stats.tvmSolve(k, store.numbers, begin: store.options["pmtTiming", default: 0] == 1)
                store.numbers[k] = v
                tvmSolved = k
            } catch let e as CalcError { fail(e) } catch { fail(.syntax) }
            return
        }

        switch key {
        case .up:
            commitEditorNumber()
            editorRow = max(0, editorRow - 1)
            syncEditorCol(id)
        case .down:
            commitEditorNumber()
            editorRow = min(def.rows.count - 1, editorRow + 1)
            syncEditorCol(id)
        case .enter:
            if case .options(let r) = row {
                if r.key == "calcDraw", case .statTest(let t) = id {
                    runStatTest(t, draw: editorCol == 1)
                    return
                }
                store.options[r.key] = editorCol
                if r.key == "graph" { store.seqCache = [:]; yRow = 0 }
                if r.key == "t.Inpt" { editorRow = min(editorRow + 1, Editors.def(id, store: store).rows.count - 1); syncEditorCol(id) }
            } else {
                commitEditorNumber()
                editorRow = min(def.rows.count - 1, editorRow + 1)
                syncEditorCol(id)
            }
        case .left:
            if case .options(let r) = row { editorCol = (editorCol - 1 + r.options.count) % r.options.count }
        case .right:
            if case .options(let r) = row { editorCol = (editorCol + 1) % r.options.count }
        case .clear:
            if isNumber, editorTyping { editorBuffer = []; editorTyping = false }
            else if isNumber, case .number(let k, _) = row, id == .window || id == .tblset || id == .tvm { store.numbers[k] = 0 }
            else { screen = .home }
        case .del:
            if editorTyping, !editorBuffer.isEmpty { editorBuffer.removeLast() }
        default:
            let action = resolve(key, mod)
            if isNumber, case .insert(let s) = action {
                if !editorTyping { editorBuffer = []; editorTyping = true }
                editorBuffer += Array(s)
                return
            }
            if routeNavigation(action) { return }
        }
    }

    func commitEditorNumber() {
        guard editorTyping, case .editor(let id) = screen else { editorTyping = false; return }
        let def = Editors.def(id, store: store)
        guard editorRow < def.rows.count, case .number(let key, _) = def.rows[editorRow] else { editorTyping = false; return }
        let text = String(editorBuffer)
        editorTyping = false
        editorBuffer = []
        if text.isEmpty { return }
        do {
            store.numbers[key] = try Evaluator.number(text, ctx: EvalContext(store: store))
            tvmSolved = nil
            store.seqCache = [:]
        } catch let e as CalcError { fail(e) } catch { fail(.syntax) }
    }

    private func runStatTest(_ t: StatTest, draw: Bool) {
        commitEditorNumber()
        do {
            let r = try t.run(store: store)
            for (k, v) in r.values { store.stats[k] = v }
            if draw, let (kind, params, lo, hi) = r.draw {
                // Auto window around the distribution, like the real DRAW option.
                let (xmin, xmax, ymax): (Double, Double, Double)
                switch kind {
                case "t", "norm": (xmin, xmax, ymax) = (-4, 4, 0.5)
                case "chi2": let df = params.first ?? 1; (xmin, xmax, ymax) = (0, max(10, df * 3), min(0.5, Stats.chi2PDF(max(0.5, df - 2), df) * 1.2 + 0.02))
                default: (xmin, xmax, ymax) = (0, 6, 1)
                }
                Graphing.setWindow(store, xmin, xmax, 1, -ymax * 0.15, ymax, 0.1)
                store.options["axes"] = 0
                let cap = r.lines.dropFirst().prefix(2).map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
                store.drawings = [.dist(kind, params, lo, hi, cap)]
                openGraph(.view)
                return
            }
            screen = .message(Array(r.lines.prefix(10)))
            returnScreen = .home
        } catch let e as CalcError { fail(e) } catch { fail(.syntax) }
    }

    // MARK: - Y= editor

    private func handleYEquals(_ key: KeyID, _ mod: Modifier) {
        let action = resolve(key, mod)
        if routeNavigation(action) { return }
        let last = yKeys.count - 1
        switch action {
        case .insert(let s): insert(s)
        case .up: commitYRow(); yRow = max(0, yRow - 1); loadYRow()
        case .down, .enter: commitYRow(); yRow = min(last, yRow + 1); loadYRow()
        case .clear: entry = []; cursor = 0
        case .del: deleteAtCursor()
        case .ins: insertMode.toggle()
        case .lineStart: cursor = 0
        case .lineEnd: cursor = entry.count
        case .toggle:
            // TI-84 Evo ◂▸ in the Y= editor: the whole definition on its own screen.
            let key = yKeys[min(yRow, yKeys.count - 1)]
            let lines = [Self.yLabel(key)] + Self.chunk(String(entry), Self.columns)
            let back = screen
            screen = .message(Array(lines.prefix(10)))
            returnScreen = back
        case .left:
            if cursor == 0 {
                // Cursor on the "=" toggles the function on/off, like the real Y= screen.
                let key = yKeys[min(yRow, last)]
                if Self.hasToggle(key) { store.setFuncEnabled(key, !store.funcEnabled(key)) }
            } else { moveCursorLeft() }
        case .right: moveCursorRight()
        default: break
        }
    }

    // MARK: - List editor (STAT EDIT)

    private var listName: String { "L\(listCol + 1)" }

    private func handleListEditor(_ key: KeyID, _ mod: Modifier) {
        let count = store.lists[listName]?.count ?? 0
        switch key {
        case .up: commitListCell(); listRow = max(0, listRow - 1)
        case .down: commitListCell(); listRow = min(store.lists[listName]?.count ?? 0, listRow + 1)
        case .enter: commitListCell(); listRow = min(store.lists[listName]?.count ?? 0, listRow + 1)
        case .left: commitListCell(); listCol = max(0, listCol - 1); listRow = min(listRow, store.lists[listName]?.count ?? 0)
        case .right: commitListCell(); listCol = min(5, listCol + 1); listRow = min(listRow, store.lists[listName]?.count ?? 0)
        case .del:
            if editorTyping { if !editorBuffer.isEmpty { editorBuffer.removeLast() } }
            else if listRow < count { store.lists[listName]?.remove(at: listRow) }
        case .clear:
            if editorTyping { editorBuffer = []; editorTyping = false } else { screen = .home }
        default:
            let action = resolve(key, mod)
            if case .insert(let s) = action {
                if !editorTyping { editorBuffer = []; editorTyping = true }
                editorBuffer += Array(s)
                return
            }
            commitListCell()
            _ = routeNavigation(action)
        }
    }

    func commitListCell() {
        guard editorTyping else { return }
        let text = String(editorBuffer)
        editorTyping = false
        editorBuffer = []
        guard !text.isEmpty else { return }
        do {
            let v = try Evaluator.number(text, ctx: EvalContext(store: store))
            var list = store.lists[listName] ?? []
            if listRow < list.count { list[listRow] = v } else { list.append(v) }
            store.lists[listName] = list
        } catch let e as CalcError { fail(e) } catch { fail(.syntax) }
    }

    // MARK: - Matrix editor

    private func handleMatrixEditor(_ key: KeyID, _ mod: Modifier) {
        guard let m = store.matrices[matName] else { screen = .home; return }
        let (rows, cols) = Matrix.dims(m)
        switch key {
        case .up:
            commitMatrixCell()
            if matRow > -1 { matRow -= 1 }
            if matRow == -1 { matCol = min(matCol, 1) }
        case .down, .enter:
            commitMatrixCell()
            if matRow == -1 {
                // Dimension row: enter moves rows → cols, then into the grid.
                if key == .enter && matCol == 0 { matCol = 1 } else { matRow = 0; matCol = 0 }
            }
            else if key == .enter {
                if matCol < cols - 1 { matCol += 1 } else if matRow < rows - 1 { matRow += 1; matCol = 0 }
            } else if matRow < rows - 1 { matRow += 1 }
        case .left:
            commitMatrixCell()
            matCol = max(0, matCol - 1)
        case .right:
            commitMatrixCell()
            matCol = min((matRow == -1 ? 1 : cols - 1), matCol + 1)
        case .del:
            if editorTyping, !editorBuffer.isEmpty { editorBuffer.removeLast() }
        case .clear:
            if editorTyping { editorBuffer = []; editorTyping = false } else { screen = .home }
        default:
            let action = resolve(key, mod)
            if case .insert(let s) = action {
                if !editorTyping { editorBuffer = []; editorTyping = true }
                editorBuffer += Array(s)
                return
            }
            commitMatrixCell()
            _ = routeNavigation(action)
        }
    }

    /// Cells accept complex values too ([A] becomes a complex matrix once any cell has an imaginary part).
    func commitMatrixCell() {
        guard editorTyping, var m = store.matrixRows(matName) else { editorTyping = false; return }
        let text = String(editorBuffer)
        editorTyping = false
        editorBuffer = []
        guard !text.isEmpty else { return }
        do {
            guard let z = try Evaluator.evaluate(text, ctx: EvalContext(store: store)).asComplex else { throw CalcError.dataType }
            if matRow == -1 {
                guard z.1 == 0 else { throw CalcError.dataType }
                let n = Int(z.0)
                guard n >= 1, n <= 20 else { throw CalcError.invalidDim }
                let (r, c) = Matrix.dims(m)
                let newR = matCol == 0 ? n : r, newC = matCol == 1 ? n : c
                m = (0..<newR).map { i in (0..<newC).map { j in (i < r && j < c) ? m[i][j] : .zero } }
            } else {
                m[matRow][matCol] = Cx(re: z.0, im: z.1)
            }
            store.setMatrix(matName, m)
        } catch let e as CalcError { fail(e) } catch { fail(.syntax) }
    }

    // MARK: - Graph

    private func handleGraph(_ key: KeyID, _ mod: Modifier) {
        let w = GraphWindow(store: store)
        let (pmin, pmax, pstep) = Graphing.parameterRange(store)
        let xPixel = (w.xmax - w.xmin) / Double(Int(Graphing.size.width) - 1)
        let yPixel = (w.ymax - w.ymin) / Double(Int(Graphing.size.height) - 1)
        let defined = Graphing.definedFunctions(store)
        let action = resolve(key, mod)

        if case .openTrace = action {
            if !defined.isEmpty { graphMode = .trace; calcResult = nil }
            return
        }
        if routeNavigation(action) { return }

        // Free cursor modes: ZBox and Pen.
        if graphMode == .zbox || graphMode == .pen {
            switch action {
            case .clear: graphMode = .view; zboxFirst = nil; penDown = false
            case .left, .right, .up, .down:
                switch action {
                case .left: traceX -= xPixel
                case .right: traceX += xPixel
                case .up: cursorY += yPixel
                default: cursorY -= yPixel
                }
                traceX = min(w.xmax, max(w.xmin, traceX))
                cursorY = min(w.ymax, max(w.ymin, cursorY))
                if graphMode == .pen, penDown { addPenPixel(w) }
            case .enter:
                if graphMode == .zbox {
                    if let (x1, y1) = zboxFirst {
                        Graphing.zoom(.box(x1, y1, traceX, cursorY), store: store)
                        openGraph(.view)
                    } else {
                        zboxFirst = (traceX, cursorY)
                    }
                } else {
                    penDown.toggle()
                    if penDown { addPenPixel(w) }
                }
            default: break
            }
            return
        }

        switch action {
        case .clear: screen = .home; graphMode = .view
        case .left, .right:
            if graphMode == .view { if defined.isEmpty { return }; graphMode = .trace }
            calcResult = nil
            graphBuffer = []
            let step = store.graphType == .function ? xPixel : pstep
            let previous = traceX
            traceX += (action == .left ? -step : step)
            traceX = min(pmax, max(pmin, traceX))
            // TI-84 Evo Points of Interest: the cursor snaps to a zero, extremum, y-intercept or intersection it steps over.
            if store.evo, store.options["poi", default: 0] == 0, graphMode == .trace,
               let p = Graphing.pointOfInterest(traceFn, from: previous, to: traceX, store: store) {
                traceX = p.x
                calcResult = CalcResult(label: p.label, x: p.x, y: p.y)
            }
        case .up, .down:
            guard let i = defined.firstIndex(of: traceFn), !defined.isEmpty else { return }
            if graphMode == .view { graphMode = .trace }
            traceFn = defined[(i + (action == .up ? 1 : defined.count - 1)) % defined.count]
        case .insert(let s):
            if graphMode == .view && !defined.isEmpty { graphMode = .trace }
            if graphMode != .view, s.first.map({ $0.isNumber || $0 == "." || $0 == "⁻" }) == true {
                graphBuffer += Array(s)
            }
        case .del:
            if !graphBuffer.isEmpty { graphBuffer.removeLast() }
        case .enter:
            if !graphBuffer.isEmpty {
                if let v = try? Evaluator.number(String(graphBuffer), ctx: EvalContext(store: store)) { traceX = min(pmax, max(pmin, v)) }
                graphBuffer = []
                if case .calc = graphMode {} else { return }
            }
            if case .calc(let op) = graphMode { advanceCalc(op) }
        default: break
        }
    }

    private func addPenPixel(_ w: GraphWindow) {
        let col = (w.px(traceX, Graphing.size) * Graphing.tiPixels.width / Graphing.size.width).rounded()
        let row = (w.py(cursorY, Graphing.size) * Graphing.tiPixels.height / Graphing.size.height).rounded()
        let p = Drawing.pixel(Double(row), Double(col))
        if !store.drawings.contains(p) { store.drawings.append(p) }
    }

    private func advanceCalc(_ op: CalcOp) {
        do {
            switch op {
            case .value:
                guard let (x, y) = Graphing.point(traceFn, at: traceX, store: store) else { throw CalcError.undefined }
                calcResult = CalcResult(label: "", x: x, y: y)
            case .derivative:
                let d = try Graphing.derivative(traceFn, at: traceX, store: store)
                let (x, y) = Graphing.point(traceFn, at: traceX, store: store) ?? (traceX, 0)
                calcResult = CalcResult(label: "dy/dx=\(ResultFormatter.format(.num(d), store: store))", x: x, y: y)
            case .intersect:
                if calcStage < 2 { calcFns.append(traceFn) }
                else {
                    let x = try Graphing.intersect(calcFns[0], calcFns[1], guess: traceX, store: store)
                    traceX = x
                    calcResult = CalcResult(label: "Intersection", x: x, y: Graphing.y(calcFns[0], at: x, store: store) ?? 0)
                }
            case .integral:
                calcBounds.append(traceX)
                if calcBounds.count == 2 {
                    let v = try Graphing.integral(traceFn, calcBounds[0], calcBounds[1], store: store)
                    calcResult = CalcResult(label: "∫f(x)dx=\(ResultFormatter.format(.num(v), store: store))", x: traceX, y: Graphing.y(traceFn, at: traceX, store: store) ?? 0)
                }
            case .zero, .minimum, .maximum:
                calcBounds.append(traceX)
                if calcBounds.count == 3 {
                    let lo = min(calcBounds[0], calcBounds[1]), hi = max(calcBounds[0], calcBounds[1])
                    let x: Double
                    switch op {
                    case .zero: x = try Graphing.zero(traceFn, lo, hi, store: store)
                    case .minimum: x = try Graphing.extremum(traceFn, lo, hi, isMax: false, store: store)
                    default: x = try Graphing.extremum(traceFn, lo, hi, isMax: true, store: store)
                    }
                    traceX = x
                    calcResult = CalcResult(label: op.label, x: x, y: Graphing.y(traceFn, at: x, store: store) ?? 0)
                }
            }
            calcStage += 1
            if let r = calcResult {
                store.reals["X"] = r.x
                store.reals["Y"] = r.y
                if op == .integral || op == .derivative {
                    let tail = r.label.split(separator: "=").last.map { String($0) } ?? ""
                    store.ans = .num((try? Evaluator.number(tail, ctx: EvalContext(store: store))) ?? r.x)
                } else {
                    store.ans = .num(r.x)
                }
                graphMode = .trace
                calcStage = 0
                calcBounds = []
                calcFns = []
            }
        } catch let e as CalcError {
            graphMode = .view
            calcStage = 0; calcBounds = []; calcFns = []
            fail(e)
        } catch {
            graphMode = .view
            fail(.syntax)
        }
    }

    var calcPrompt: String? {
        guard case .calc(let op) = graphMode, calcResult == nil else { return nil }
        let prompts = op.prompts
        return calcStage < prompts.count ? prompts[calcStage] : nil
    }

    // MARK: - Table

    private func handleTable(_ key: KeyID, _ mod: Modifier) {
        let dt = store.graphType == .sequence ? 1 : (store.numbers["ΔTbl"] ?? 1)
        let columns = TableColumns.columns(store)
        switch key {
        case .up:
            if tableRow > 0 { tableRow -= 1 } else { tableStart -= dt }
        case .down:
            if tableRow < 8 { tableRow += 1 } else { tableStart += dt }
        case .left: tableCol = max(0, tableCol - 1)
        case .right: tableCol = min(columns.count, tableCol + 1)
        case .clear: screen = .home
        default:
            _ = routeNavigation(resolve(key, mod))
        }
    }

    // MARK: - Apps

    private func handleApp(_ key: KeyID, _ mod: Modifier) {
        if key == .on {
            game = nil
            screen = .home
            return
        }
        guard let g = game else { screen = .home; return }
        if key == .clear, !g.handlesClear {
            game = nil
            screen = .home
            return
        }
        g.handle(key, resolve(key, mod))
        if g.wantsExit {
            game = nil
            screen = .home
            if store.pendingShowGraph { store.pendingShowGraph = false; openGraph(.view) }
        }
    }

    // MARK: - Solver

    func openSolver() {
        homeEntryBackup = entry
        homeCursorBackup = cursor
        entry = Array(store.solverEqn)
        cursor = entry.count
        solverStage = 0
        solverRow = 0
        solverSolved = nil
        editorBuffer = []; editorTyping = false
        screen = .solver
        returnScreen = .home
    }

    var solverVariables: [String] { Solver.variables(in: store.solverEqn) }

    private func handleSolver(_ key: KeyID, _ mod: Modifier) {
        let action = resolve(key, mod)
        if solverStage == 0 {
            switch action {
            case .insert(let s): insert(s)
            case .del: deleteAtCursor()
            case .ins: insertMode.toggle()
            case .left: moveCursorLeft()
            case .right: moveCursorRight()
            case .lineStart: cursor = 0
            case .lineEnd: cursor = entry.count
            case .openMenu(let id):
                openMenu(id, from: .solver)   // the equation stays on screen behind the menu
            case .clear:
                if entry.isEmpty { leaveSolver() } else { entry = []; cursor = 0 }
            case .enter, .down:
                store.solverEqn = String(entry)
                guard !store.solverEqn.isEmpty else { return }
                for v in solverVariables where store.reals[v] == nil { store.reals[v] = 0 }
                solverStage = 1
                solverRow = 0
                solverSolved = nil
            default:
                if routeNavigation(action) { entry = homeEntryBackup; cursor = min(homeCursorBackup, entry.count) }
            }
            return
        }
        let vars = solverVariables
        let rowCount = vars.count + 1   // variable rows + bound row
        switch action {
        case .insert(let s):
            if !editorTyping { editorBuffer = []; editorTyping = true }
            editorBuffer += Array(s)
        case .del:
            if editorTyping, !editorBuffer.isEmpty { editorBuffer.removeLast() }
        case .up:
            commitSolverValue()
            if solverRow == 0 { solverStage = 0; entry = Array(store.solverEqn); cursor = entry.count }
            else { solverRow -= 1 }
        case .down:
            commitSolverValue()
            solverRow = min(rowCount - 1, solverRow + 1)
        case .enter:
            // alpha+ENTER solves on the CE; the Evo has no SOLVE legend, so ENTER solves a row you are
            // not typing into (typing a value and pressing ENTER still just stores the guess).
            let wasTyping = editorTyping
            commitSolverValue()
            let solveNow = (mod == .alpha || mod == .alphaLock) || (model == .evo && !wasTyping)
            if solveNow, solverRow < vars.count {
                solveSolver(for: vars[solverRow])
            } else {
                solverRow = min(rowCount - 1, solverRow + 1)
            }
        case .clear:
            if editorTyping { editorBuffer = []; editorTyping = false } else { leaveSolver() }
        case .openMenu(let id):
            openMenu(id, from: .solver)
        default:
            commitSolverValue()
            if routeNavigation(action) { entry = homeEntryBackup; cursor = min(homeCursorBackup, entry.count) }
        }
    }

    /// Solves the equation for one variable and marks the row with the CE's ■.
    private func solveSolver(for name: String) {
        do {
            let x = try Solver.solve(store.solverEqn, for: name,
                                     guess: store.reals[name] ?? 0,
                                     lo: solverBounds.lo, hi: solverBounds.hi, store: store)
            store.reals[name] = x
            solverSolved = name
        } catch let e as CalcError { fail(e) } catch { fail(.syntax) }
    }

    /// The search interval, edited on the solver's bound row.
    var solverBounds: (lo: Double, hi: Double) {
        (store.numbers["solverLo"] ?? -Solver.defaultBound, store.numbers["solverHi"] ?? Solver.defaultBound)
    }

    /// Text a solver row shows when it is not being typed into.
    func solverRowText(_ row: Int) -> String {
        let vars = solverVariables
        if row < vars.count { return ResultFormatter.number(store.reals[vars[row]] ?? 0, notation: store.notation, fixed: store.fixedDigits) }
        let b = solverBounds
        return "{" + ResultFormatter.number(b.lo) + "," + ResultFormatter.number(b.hi) + "}"
    }

    func commitSolverValue() {
        guard editorTyping else { return }
        let text = String(editorBuffer)
        editorTyping = false
        editorBuffer = []
        let vars = solverVariables
        guard !text.isEmpty else { return }
        do {
            if solverRow < vars.count {
                store.reals[vars[solverRow]] = try Evaluator.number(text, ctx: EvalContext(store: store))
                solverSolved = nil
            } else {
                // bound={lo,hi}
                let v = try Evaluator.evaluate(text, ctx: EvalContext(store: store))
                let l = try v.listValue()
                guard l.count == 2, l[0] < l[1] else { throw CalcError.invalidDim }
                store.numbers["solverLo"] = l[0]
                store.numbers["solverHi"] = l[1]
            }
        }
        catch let e as CalcError { fail(e) } catch { fail(.syntax) }
    }

    private func leaveSolver() {
        if solverStage == 0 { store.solverEqn = String(entry) }
        entry = homeEntryBackup
        cursor = min(homeCursorBackup, entry.count)
        screen = .home
    }

    // MARK: - MEM variable lists, confirmations, groups

    private func handleVarList(_ mode: VarListMode, _ key: KeyID, _ mod: Modifier) {
        let items = varListItems(mode)
        switch key {
        case .up: varListRow = max(0, varListRow - 1)
        case .down: varListRow = min(max(0, items.count - 1), varListRow + 1)
        case .clear: screen = .home
        case .enter:
            guard varListRow < items.count else { return }
            let name = items[varListRow].name
            if items[varListRow].category == "Apps" { return }
            if store.archived.contains(name) { store.archived.remove(name) } else { store.archived.insert(name) }
            varListRow = min(varListRow, max(0, varListItems(mode).count - 1))
        case .del:
            guard case .manage = mode, varListRow < items.count, items[varListRow].category != "Apps" else { return }
            let name = items[varListRow].name
            returnScreen = screen
            screen = .confirm(.deleteVariable(name))
        default:
            _ = routeNavigation(resolve(key, mod))
        }
    }

    private func handleConfirm(_ kind: ConfirmKind, _ key: KeyID) {
        let yes = key == .two || key == .enter
        let no = key == .one || key == .clear
        guard yes || no else { return }
        let back = returnScreen
        returnScreen = .home
        switch kind {
        case .programLock(let name):
            if yes { store.lockedPrograms.insert(name) }
            openProgramEditor(name)           // a brand-new program still opens so it can be written
            return
        case .programUnlock(let name):
            if yes { store.lockedPrograms.remove(name); openProgramEditor(name) } else { screen = .home }
            return
        default: break
        }
        if no { screen = (kind == .garbageCollect || isDeleteConfirm(kind)) ? back : .home; return }
        switch kind {
        case .resetRAM:
            store.reset()
            history = []; entry = []; cursor = 0
            screen = .message(["", "", "       RAM cleared", "", "", "", "", "", "", "  Press CLEAR to continue"])
        case .resetDefaults:
            store.options = VariableStore.defaultOptions
            store.numbers = VariableStore.defaultNumbers
            screen = .message(["", "", "     Defaults set", "", "", "", "", "", "", "  Press CLEAR to continue"])
        case .resetArchiveVars:
            store.resetArchive(vars: true, apps: false)
            screen = .message(["", "", "    Archive cleared", "", "", "", "", "", "", "  Press CLEAR to continue"])
        case .resetArchiveApps:
            store.resetArchive(vars: false, apps: true)
            screen = .message(["", "", "     Apps cleared", "", "", "", "", "", "", "  Press CLEAR to continue"])
        case .resetArchiveBoth:
            store.resetArchive(vars: true, apps: true)
            screen = .message(["", "", "    Archive cleared", "", "", "", "", "", "", "  Press CLEAR to continue"])
        case .garbageCollect:
            screen = .message(["", "", "  Garbage collection", "  complete.", "", "", "", "", "", "  Press CLEAR to continue"])
        case .deleteVariable(let name):
            store.deleteVariable(name)
            screen = back
            if case .varList(let m) = back { varListRow = min(varListRow, max(0, varListItems(m).count - 1)) }
        case .programLock, .programUnlock:
            break
        }
    }

    private func isDeleteConfirm(_ kind: ConfirmKind) -> Bool { if case .deleteVariable = kind { return true }; return false }

    /// NEW program / group name prompt (alpha-lock is on).
    private func handleNameEntry(_ key: KeyID, _ mod: Modifier) {
        let action = resolve(key, mod)
        switch action {
        case .insert(let s):
            guard nameBuffer.count < 8 else { return }
            let ch = s.uppercased()
            if let c = ch.first, c.isLetter || (c.isNumber && !nameBuffer.isEmpty), c != " " { nameBuffer.append(c) }
        case .del:
            if !nameBuffer.isEmpty { nameBuffer.removeLast() }
        case .clear:
            modifier = .none
            screen = .home
        case .enter:
            let name = String(nameBuffer)
            guard !name.isEmpty else { return }
            modifier = .none
            if screen == .programName {
                if store.programs[name] == nil { store.programs[name] = [""] }
                if store.lockedPrograms.contains(name) { screen = .confirm(.programUnlock(name)) }
                else { screen = .confirm(.programLock(name)) }
                returnScreen = .home
            } else {
                store.groups[name] = store.makeGroup()
                screen = .message(["", "", "  Group \(name) created", "  from all variables.", "", "", "", "", "", "  Press CLEAR to continue"])
            }
        default:
            break
        }
    }

    // MARK: - Program editor

    private func handleProgramEditor(_ key: KeyID, _ mod: Modifier) {
        let action = resolve(key, mod)
        if key == .prgm, mod == .none {
            commitProgramLine()
            openMenu(.prgmCtl, from: screen)
            return
        }
        switch action {
        case .insert(let s): insert(s)
        case .del:
            if entry.isEmpty, programLines.count > 1 {
                programLines.remove(at: programRow)
                programRow = min(programRow, programLines.count - 1)
                entry = Array(programLines[programRow]); cursor = entry.count
                store.programs[programName] = programLines
            } else { deleteAtCursor() }
        case .ins: insertMode.toggle()
        case .left: moveCursorLeft()
        case .right: moveCursorRight()
        case .up:
            commitProgramLine()
            programRow = max(0, programRow - 1)
            entry = Array(programLines[programRow]); cursor = entry.count
        case .down:
            commitProgramLine()
            programRow = min(programLines.count - 1, programRow + 1)
            entry = Array(programLines[programRow]); cursor = entry.count
        case .enter:
            // Split the line at the cursor: the rest moves to a new line.
            let head = Array(entry.prefix(cursor)), tail = Array(entry.dropFirst(cursor))
            programLines[programRow] = String(head)
            programLines.insert(String(tail), at: programRow + 1)
            programRow += 1
            entry = tail; cursor = 0
            store.programs[programName] = programLines
        case .clear:
            entry = []; cursor = 0
        case .openMenu(let id):
            commitProgramLine()
            openMenu(id, from: screen)
        case .openYEquals, .openGraph, .openTrace, .openTable, .openEditor:
            commitProgramLine()
            entry = homeEntryBackup; cursor = min(homeCursorBackup, entry.count)
            _ = routeNavigation(action)
        default: break
        }
    }

    func commitProgramLine() {
        guard case .programEditor = screen else { return }
        guard programRow < programLines.count else { return }
        programLines[programRow] = String(entry)
        store.programs[programName] = programLines
    }
}

/// Columns of the TABLE screen in the current graph mode.
enum TableColumns {
    struct Column {
        let label: String
        let value: (Double) -> Double?
    }

    static func columns(_ store: VariableStore) -> [Column] {
        let subs = Tokenizer.subscripts
        switch store.graphType {
        case .function:
            return Graphing.definedFunctions(store).map { n in Column(label: "Y\(subs[n])") { Graphing.y(n, at: $0, store: store) } }
        case .parametric:
            return Graphing.definedFunctions(store).flatMap { n in
                [Column(label: "X\(subs[n])T") { Graphing.point(n, at: $0, store: store)?.0 },
                 Column(label: "Y\(subs[n])T") { Graphing.point(n, at: $0, store: store)?.1 }]
            }
        case .polar:
            return Graphing.definedFunctions(store).map { n in
                Column(label: "r\(subs[n])") { p in store.funcs["r\(n)"].flatMap { Graphing.evaluate($0, with: ["θ": p], store: store) } }
            }
        case .sequence:
            return Graphing.definedFunctions(store).map { n in
                Column(label: "\(Sequences.names[n - 1])(n)") { Graphing.point(n, at: $0, store: store)?.1 }
            }
        }
    }
}
