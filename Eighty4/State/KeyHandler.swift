import Foundation

extension CalculatorState {
    // MARK: - Entry point

    func press(_ key: KeyID) {
        defer { store.save() }

        if screen == .off {
            if key == .on { screen = .home; modifier = .none }
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
            screen = returnScreen
            returnScreen = .home
            return
        }
        if mod == .second && key == .on { turnOff(); return }
        if mod == .second && key == .mode { quitToHome(); return }

        switch screen {
        case .home: handleHome(key, mod)
        case .menu(let id): handleMenu(id, key, mod)
        case .editor(let id): handleEditor(id, key, mod)
        case .yEquals: handleYEquals(key, mod)
        case .listEditor: handleListEditor(key, mod)
        case .matrixEditor: handleMatrixEditor(key, mod)
        case .graph: handleGraph(key, mod)
        case .table: handleTable(key, mod)
        case .app: handleApp(key, mod)
        case .linkReceive:
            screen = .error("ERR:Error in Xmit")
            returnScreen = .home
        case .message, .about, .memMgmt:
            if key == .clear || key == .enter { screen = .home }
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
        if mod == .alpha || mod == .alphaLock, let a = Keymap.spec(key)?.alpha, let ch = alphaCharacter(a) {
            return .insert(ch)
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
        case .multiply: return .insert("×")
        case .divide: return .insert("÷")
        case .power: return .insert("^")
        case .square: return .insert("²")
        case .inverse: return .insert("⁻¹")
        case .lparen: return .insert("(")
        case .rparen: return .insert(")")
        case .comma: return .insert(",")
        case .xtn: return .insert("X")
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
        case .vars: return .openMenu(.distr)
        case .inverse: return .openMenu(.matrix)
        case .sin: return .insert("sin⁻¹(")
        case .cos: return .insert("cos⁻¹(")
        case .tan: return .insert("tan⁻¹(")
        case .power: return .insert("π")
        case .square: return .insert("√(")
        case .comma: return .insert("ᴇ")
        case .lparen: return .insert("{")
        case .rparen: return .insert("}")
        case .divide: return .insert("e")
        case .log: return .insert("10^(")
        case .ln: return .insert("e^(")
        case .multiply: return .insert("[")
        case .minus: return .insert("]")
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
        case .plus: return .openMenu(.mem)
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
            let from: Screen = (screen == .yEquals) ? .yEquals : .home
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

    private func leaveEditorsIfNeeded(keepY: Bool) {
        switch screen {
        case .yEquals: if !keepY { leaveYEquals() } else { commitYRow() }
        case .editor: commitEditorNumber()
        case .listEditor: commitListCell()
        case .matrixEditor: commitMatrixCell()
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
        let def = Editors.def(id)
        guard editorRow < def.rows.count else { return }
        if case .options(let r) = def.rows[editorRow] { editorCol = store.options[r.key] ?? 0 } else { editorCol = 0 }
    }

    func enterYEquals() {
        if screen == .home {
            homeEntryBackup = entry
            homeCursorBackup = cursor
        }
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

    private func yIndex(_ row: Int) -> Int { row == 9 ? 0 : row + 1 }

    func loadYRow() {
        entry = Array(store.yFuncs[yIndex(yRow)] ?? "")
        cursor = entry.count
    }

    func commitYRow() {
        let text = String(entry)
        store.yFuncs[yIndex(yRow)] = text.isEmpty ? nil : text
    }

    func openGraph(_ mode: GraphMode) {
        let w = GraphWindow(store: store)
        guard w.isValid else { fail(.windowRange); return }
        graphSamples = Graphing.samples(store)
        let defined = Graphing.definedFunctions(store)
        if !defined.contains(traceFn) { traceFn = defined.first ?? 1 }
        traceX = (w.xmin + w.xmax) / 2
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
        tableRow = 0
        tableCol = 0
        screen = .table
        returnScreen = .home
    }

    func startApp(_ id: AppID) {
        switch id {
        case .geoDash: game = GeoDashGame()
        case .tetris: game = TetrisGame()
        }
        screen = .app(id)
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
        if routeNavigation(action) { return }
        switch action {
        case .insert(let s): historyIndex = nil; insert(s)
        case .enter: evaluate()
        case .entry:
            if entry.isEmpty, let last = store.entries.last { entry = Array(last); cursor = entry.count }
            else { evaluate() }
        case .clear:
            if entry.isEmpty { history = [] } else { entry = []; cursor = 0 }
            historyIndex = nil
        case .del: deleteAtCursor()
        case .ins: insertMode.toggle()
        case .left: cursor = max(0, cursor - 1)
        case .right: cursor = min(entry.count, cursor + 1)
        case .up: recallEntry(step: -1)
        case .down: recallEntry(step: 1)
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
        default:
            if id == .catalog, let a = Keymap.spec(key)?.alpha, let ch = alphaCharacter(a), ch != " " {
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
        if screen == .yEquals { returnScreen = .yEquals } else { returnScreen = .home }
    }

    private func select(_ item: MenuItem) {
        switch item.action {
        case .insert(let s):
            closeMenu()
            if screen == .home || screen == .yEquals { insert(s) }
            else { screen = .home; insert(s) }
        case .submenu(let id):
            menuTab = 0; menuRow = 0
            screen = .menu(id)
        case .editor(let id):
            if returnScreen == .yEquals { leaveYEquals() }
            openEditor(id)
        case .app(let id):
            if returnScreen == .yEquals { leaveYEquals() }
            startApp(id)
        case .command(let c):
            runCommand(c)
        }
    }

    private func showMessage(_ lines: [String]) {
        if returnScreen == .yEquals { leaveYEquals() }
        screen = .message(lines)
        returnScreen = .home
    }

    private func runCommand(_ c: Command) {
        switch c {
        case .zoom(let kind):
            if returnScreen == .yEquals { leaveYEquals() }
            let center: (Double, Double)? = (screen == .graph || returnScreen == .graph) ? (traceX, Graphing.y(traceFn, at: traceX, store: store) ?? 0) : nil
            Graphing.zoom(kind, store: store, center: center)
            openGraph(.view)
        case .clearEntries:
            store.entries = []
            closeMenu(); screen = .home
            appendHistory(expr: "Clear Entries", result: "Done")
        case .resetAll:
            store.reset()
            history = []; entry = []; cursor = 0
            showMessage(["", "", "       RAM cleared", "", "", "", "", "", "", "  Press CLEAR to continue"])
        case .resetDefaults:
            store.options = VariableStore.defaultOptions
            store.numbers = VariableStore.defaultNumbers
            showMessage(["", "", "     Defaults set", "", "", "", "", "", "", "  Press CLEAR to continue"])
        case .about:
            if returnScreen == .yEquals { leaveYEquals() }
            screen = .about; returnScreen = .home
        case .memMgmt:
            if returnScreen == .yEquals { leaveYEquals() }
            screen = .memMgmt; returnScreen = .home
        case .oneVar, .twoVar, .linReg, .linRegAlt, .quadReg, .cubicReg, .quartReg, .expReg, .lnReg, .pwrReg, .medMed:
            runStatCalc(c)
        case .listEditor:
            if returnScreen == .yEquals { leaveYEquals() }
            listRow = 0; listCol = 0
            editorBuffer = []; editorTyping = false
            screen = .listEditor; returnScreen = .home
        case .matrixEdit(let name):
            if returnScreen == .yEquals { leaveYEquals() }
            matName = name
            if store.matrices[name] == nil { store.matrices[name] = [[0]] }
            matRow = -1; matCol = 0
            editorBuffer = []; editorTyping = false
            screen = .matrixEditor(name); returnScreen = .home
        case .programsReadOnly:
            showMessage(["", "", "  Programs are read-only", "  in Eighty4 v0.2.0.", "", "  Run them from PRGM EXEC", "  or the APPS menu.", "", "", "  Press CLEAR to continue"])
        case .calc(let op):
            if returnScreen == .yEquals { leaveYEquals() }
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
        case .notAvailable(let label):
            showMessage(["", "", "  \(label)", "", "  is not available in", "  Eighty4 v0.2.0.", "", "", "", "  Press CLEAR to continue"])
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
            default:
                return
            }
            for (k, v) in pairs {
                store.stats[k] = v
                lines.append(" \(k)=\(fmt(v))")
            }
            if returnScreen == .yEquals { leaveYEquals() }
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
        let def = Editors.def(id)
        let row = def.rows[min(editorRow, def.rows.count - 1)]
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
                store.options[r.key] = editorCol
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
        let def = Editors.def(id)
        guard editorRow < def.rows.count, case .number(let key, _) = def.rows[editorRow] else { editorTyping = false; return }
        let text = String(editorBuffer)
        editorTyping = false
        editorBuffer = []
        if text.isEmpty { return }
        do {
            store.numbers[key] = try Evaluator.number(text, ctx: EvalContext(store: store))
            tvmSolved = nil
        } catch let e as CalcError { fail(e) } catch { fail(.syntax) }
    }

    // MARK: - Y= editor

    private func handleYEquals(_ key: KeyID, _ mod: Modifier) {
        let action = resolve(key, mod)
        if routeNavigation(action) { return }
        switch action {
        case .insert(let s): insert(s)
        case .up: commitYRow(); yRow = max(0, yRow - 1); loadYRow()
        case .down, .enter: commitYRow(); yRow = min(9, yRow + 1); loadYRow()
        case .clear: entry = []; cursor = 0
        case .del: deleteAtCursor()
        case .ins: insertMode.toggle()
        case .left: cursor = max(0, cursor - 1)
        case .right: cursor = min(entry.count, cursor + 1)
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
        guard var m = store.matrices[matName] else { screen = .home; return }
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
            m = store.matrices[matName] ?? m
            _ = routeNavigation(action)
        }
    }

    func commitMatrixCell() {
        guard editorTyping, var m = store.matrices[matName] else { editorTyping = false; return }
        let text = String(editorBuffer)
        editorTyping = false
        editorBuffer = []
        guard !text.isEmpty else { return }
        do {
            let v = try Evaluator.number(text, ctx: EvalContext(store: store))
            if matRow == -1 {
                let n = Int(v)
                guard n >= 1, n <= 20 else { throw CalcError.invalidDim }
                let (r, c) = Matrix.dims(m)
                let newR = matCol == 0 ? n : r, newC = matCol == 1 ? n : c
                m = (0..<newR).map { i in (0..<newC).map { j in (i < r && j < c) ? m[i][j] : 0 } }
            } else {
                m[matRow][matCol] = v
            }
            store.matrices[matName] = m
        } catch let e as CalcError { fail(e) } catch { fail(.syntax) }
    }

    // MARK: - Graph

    private func handleGraph(_ key: KeyID, _ mod: Modifier) {
        let w = GraphWindow(store: store)
        let step = (w.xmax - w.xmin) / Double(Int(Graphing.size.width) - 1)
        let defined = Graphing.definedFunctions(store)
        let action = resolve(key, mod)

        if case .openTrace = action {
            if !defined.isEmpty { graphMode = .trace; calcResult = nil }
            return
        }
        if routeNavigation(action) { return }

        switch action {
        case .clear: screen = .home; graphMode = .view
        case .left, .right:
            if graphMode == .view { if defined.isEmpty { return }; graphMode = .trace }
            calcResult = nil
            graphBuffer = []
            traceX += (action == .left ? -step : step)
            traceX = min(w.xmax, max(w.xmin, traceX))
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
                if let v = try? Evaluator.number(String(graphBuffer), ctx: EvalContext(store: store)) { traceX = v }
                graphBuffer = []
                if case .calc = graphMode {} else { return }
            }
            if case .calc(let op) = graphMode { advanceCalc(op) }
        default: break
        }
    }

    private func advanceCalc(_ op: CalcOp) {
        do {
            switch op {
            case .value:
                guard let y = Graphing.y(traceFn, at: traceX, store: store) else { throw CalcError.undefined }
                calcResult = CalcResult(label: "", x: traceX, y: y)
            case .derivative:
                let d = try Graphing.derivative(traceFn, at: traceX, store: store)
                calcResult = CalcResult(label: "dy/dx=\(ResultFormatter.format(.num(d), store: store))", x: traceX, y: Graphing.y(traceFn, at: traceX, store: store) ?? 0)
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
            if calcResult != nil {
                store.reals["X"] = calcResult!.x
                store.reals["Y"] = calcResult!.y
                store.ans = .num(op == .integral || op == .derivative ? Double(calcResult!.label.split(separator: "=").last.map { String($0) }.flatMap { s -> Double? in
                    try? Evaluator.number(s, ctx: EvalContext(store: store))
                } ?? calcResult!.x) : calcResult!.x)
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
        let dt = store.numbers["ΔTbl"] ?? 1
        let defined = Graphing.definedFunctions(store)
        switch key {
        case .up:
            if tableRow > 0 { tableRow -= 1 } else { tableStart -= dt }
        case .down:
            if tableRow < 8 { tableRow += 1 } else { tableStart += dt }
        case .left: tableCol = max(0, tableCol - 1)
        case .right: tableCol = min(defined.count, tableCol + 1)
        case .clear: screen = .home
        default:
            _ = routeNavigation(resolve(key, mod))
        }
    }

    // MARK: - Apps

    private func handleApp(_ key: KeyID, _ mod: Modifier) {
        if key == .clear || key == .on {
            game = nil
            screen = .home
            return
        }
        game?.press(key)
    }
}
