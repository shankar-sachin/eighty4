import XCTest
@testable import Eighty4

/// The TI-84 Evo model: keypad, icon home screen, toggle key, templates on keys, menus, modes, POI trace.
final class EvoTests: XCTestCase {
    private var s: CalculatorState!

    override func setUp() {
        VariableStore.persistenceEnabled = false
        s = CalculatorState()
        s.model = .evo
    }

    private func keys(_ k: [KeyID]) { k.forEach { s.press($0) } }

    private func eval(_ text: String) throws -> String {
        ResultFormatter.format(try Evaluator.evaluate(text, ctx: EvalContext(store: s.store)), store: s.store)
    }

    func testKeymapAndBoot() {
        XCTAssertEqual(s.screen, .iconHome)                                     // the Evo boots to the icon home screen
        XCTAssertEqual(s.shell, .white)
        XCTAssertTrue(s.store.evo)
        XCTAssertEqual(Keymap.keys(for: .evo).count, Keymap.keys.count)
        XCTAssertEqual(Keymap.spec(.fraction, model: .evo)?.row, 4)             // n/d key where apps was
        XCTAssertEqual(Keymap.spec(.expTemplate, model: .evo)?.second, "ⁿ√")
        XCTAssertEqual(Keymap.spec(.toggle, model: .evo)?.second, "mem")
        XCTAssertEqual(Keymap.spec(.divide, model: .evo)?.alpha, "H")           // legends keep their positions
        XCTAssertEqual(Keymap.spec(.clear, model: .evo)?.second, "↰clear")
        XCTAssertNil(Keymap.spec(.apps, model: .evo))
        XCTAssertEqual(Keymap.spec(.stat, model: .evo)?.alpha, "distr")
        XCTAssertEqual(Keymap.spec(.vars, model: .evo)?.second, "matrix")
        XCTAssertEqual(Keymap.spec(.enter, model: .evo)?.alpha, nil)            // no SOLVE legend on the Evo
        XCTAssertEqual(Keymap.spec(.plus)?.second, "MEM")                       // the CE keymap is untouched
        keys([.on])                                                             // home key: Calculator app…
        XCTAssertEqual(s.screen, .home)
        keys([.on])                                                             // …and back to the icons
        XCTAssertEqual(s.screen, .iconHome)
        keys([.second, .on])
        XCTAssertEqual(s.screen, .off)
        keys([.on])
        XCTAssertEqual(s.screen, .iconHome)
    }

    func testIconHomeHelpAndPython() {
        keys([.right, .right, .down])
        XCTAssertEqual(s.iconIndex, 6)                                          // System Solver
        keys([.up, .right, .enter])                                             // Mode Settings
        XCTAssertEqual(s.screen, .editor(.mode))
        keys([.on])
        XCTAssertEqual(s.screen, .iconHome)
        s.iconIndex = HomeIcon.help.rawValue
        keys([.enter, .right])
        XCTAssertEqual(s.screen, .help(1))
        keys([.toggle])                                                         // ◂▸ leaves Help for the icons…
        XCTAssertEqual(s.screen, .iconHome)
        keys([.toggle])                                                         // …and opens it again
        XCTAssertEqual(s.screen, .help(0))
        keys([.clear])
        XCTAssertEqual(s.screen, .home)
        keys([.on])
        s.iconIndex = HomeIcon.python.rawValue
        keys([.enter])
        XCTAssertEqual(s.screen, .app(.python))
        keys([.two, .expTemplate, .one, .zero, .enter])                          // 2**10
        XCTAssertEqual((s.game as? PythonApp)?.lastOutput, "1024")
        keys([.seven, .divide, .two, .enter])
        XCTAssertEqual((s.game as? PythonApp)?.lastOutput, "3.5")
        keys([.clear])                                                          // CLEAR on an empty line leaves the shell
        XCTAssertEqual(s.screen, .home)
        keys([.on, .five])                                                      // typing on the icon screen goes to the calculator
        XCTAssertEqual(s.screen, .home)
        XCTAssertEqual(String(s.entry), "5")
    }

    func testCalculatorKeysAndToggle() {
        keys([.on, .seven, .divide, .three, .enter])
        XCTAssertEqual(s.history.last?.text, "2.333333333")
        keys([.toggle])                                                         // ◂▸ fraction…
        XCTAssertEqual(s.history.last?.text, MathPrint.fraction("7", "3"))
        keys([.toggle])                                                         // …and back
        XCTAssertEqual(s.history.last?.text, "2.333333333")
        keys([.two, .expTemplate, .five, .enter])                                // x^□ key
        XCTAssertEqual(s.history.last?.text, "32")
        keys([.fraction, .three, .right, .eight, .enter])                       // n/d key
        XCTAssertEqual(s.history.last?.text, MathPrint.fraction("3", "8"))
        keys([.log, .two, .right, .eight, .enter])                              // log key = log of any base
        XCTAssertEqual(s.history.last?.text, "3")
        keys([.log, .right, .one, .zero, .zero, .enter])                        // empty base is 10
        XCTAssertEqual(s.history.last?.text, "2")
        keys([.second, .expTemplate, .three, .right, .two, .seven, .enter])      // ⁿ√
        XCTAssertEqual(s.history.last?.text, "3")
        keys([.two, .multiply, .three, .enter])                                 // multiplication shows as a dot
        XCTAssertEqual(s.history[s.history.count - 2].text, "2⋅3")
        XCTAssertEqual(s.history.last?.text, "6")
        keys([.four, .plus, .four, .clear])                                     // 2nd+clear undoes a clear
        XCTAssertEqual(s.entry, [])
        keys([.second, .clear])
        XCTAssertEqual(String(s.entry), "4+4")
        keys([.left, .left, .nine])                                             // the bar cursor never overwrites
        XCTAssertEqual(String(s.entry), "49+4")
        keys([.clear, .second, .divide])                                        // 2nd legends are positional
        XCTAssertEqual(String(s.entry), "π")
        keys([.clear, .second, .plus])
        XCTAssertEqual(String(s.entry), "]")
        keys([.clear, .second, .toggle])
        XCTAssertEqual(s.screen, .menu(.mem))
        keys([.clear, .second, .vars])                                          // 2nd+vars is the matrix menu
        XCTAssertEqual(s.screen, .menu(.matrix))
        keys([.clear, .alpha, .stat])                                           // alpha+stat is distr
        XCTAssertEqual(s.screen, .menu(.distr))
        keys([.clear, .one, .two, .three, .second, .left])                      // 2nd+◀/▶ jump along the line
        XCTAssertEqual(s.cursor, 0)
        keys([.second, .right])
        XCTAssertEqual(s.cursor, 3)
    }

    func testMenusModesAndAngle() throws {
        keys([.on])
        XCTAssertEqual(Menus.def(.stat, store: s.store).tabs.map(\.title), ["EDIT", "CALC", "INTERVALS", "TESTS"])
        XCTAssertEqual(Menus.def(.distr, store: s.store).tabs.map(\.title), ["NORMAL", "t", "χ²", "F", "DISCRETE"])
        keys([.math, .right, .toggle])                                          // ◂▸ in a menu: syntax help for abs(
        if case .message(let lines) = s.screen { XCTAssertEqual(lines[2], " abs(value1)") } else { XCTFail("no syntax help") }
        keys([.clear])
        XCTAssertEqual(s.screen, .menu(.math))                                  // CLEAR returns to the menu
        keys([.clear])
        XCTAssertEqual(Editors.def(.mode, store: s.store).rows.count, 13)
        s.store.options["angle"] = 2                                            // GRADIAN
        XCTAssertEqual(try eval("sin(100)"), "1")
        XCTAssertEqual(try eval("cos⁻¹(0)"), "100")
        XCTAssertEqual(try eval("180°"), "200")                                 // 180 degrees is 200 gradians
        XCTAssertTrue(s.store.statusText.contains("GRADIAN"))
        s.store.options["angle"] = 0
        keys([.alpha, .yEquals])                                                // alpha+f1 FRAC shortcut
        XCTAssertEqual(s.screen, .menu(.shortcut(1)))
        keys([.clear, .alpha, .trace])
        XCTAssertEqual(s.screen, .menu(.shortcut(4)))
        keys([.one])
        XCTAssertEqual(String(s.entry), "Y₁")
        keys([.clear, .yEquals, .xtn, .square, .toggle])                        // ◂▸ in Y= expands the definition
        if case .message(let lines) = s.screen { XCTAssertEqual(lines, ["Y₁=", "X²"]) } else { XCTFail("no expanded view") }
    }

    func testRegressionsWindowAndPOI() {
        XCTAssertEqual(s.store.numbers["Xmax"], 6.6)                           // the Evo boots with ZDecimal
        s.store.lists["L1"] = [1, 2, 3, 4]
        s.store.lists["L2"] = [2, 4, 6, 8]
        keys([.on, .stat, .right, .up, .up, .up, .enter])                       // CALC … PropReg
        if case .message(let lines) = s.screen { XCTAssertEqual(lines[0], "PropReg"); XCTAssertEqual(lines[2], " a=2") } else { XCTFail("no PropReg") }
        XCTAssertEqual(s.store.regEQ, "2X")
        keys([.clear, .stat, .right, .up, .enter])                              // eBASEReg
        if case .message(let lines) = s.screen { XCTAssertEqual(lines[0], "eBASEReg") } else { XCTFail("no eBASEReg") }
        keys([.clear])

        s.store.yFuncs[1] = "X²−2"
        s.store.yFuncs[2] = "X"
        s.store.yFuncs[3] = "(X−1)²"
        keys([.graph, .trace])
        s.traceFn = 1
        s.traceX = 1.4
        keys([.right])                                                          // steps over √2: the cursor snaps to the zero
        XCTAssertEqual(s.calcResult?.label, "Zero")
        XCTAssertEqual(s.traceX, 2.0.squareRoot(), accuracy: 1e-6)
        s.traceX = -0.02
        keys([.right])
        XCTAssertEqual(s.calcResult?.label, "Y-intercept")
        XCTAssertEqual(s.calcResult?.y ?? 0, -2, accuracy: 1e-9)
        s.traceX = 1.98
        keys([.right])
        XCTAssertEqual(s.calcResult?.label, "Intersection")                     // with Y2=X at X=2
        XCTAssertEqual(s.traceX, 2, accuracy: 1e-6)
        let m = Graphing.pointOfInterest(3, from: 0.95, to: 1.05, store: s.store)
        XCTAssertEqual(m?.label, "Minimum")
        XCTAssertEqual(m?.x ?? 0, 1, accuracy: 1e-6)
        XCTAssertNil(Graphing.pointOfInterest(1, from: 3, to: 3.1, store: s.store))
        s.store.options["poi"] = 1                                              // FORMAT POI Trace: Off
        s.traceX = 1.4
        s.calcResult = nil
        keys([.right])
        XCTAssertNil(s.calcResult)
    }

    func testAppHomepageChoosesTheCalculator() {
        let a = CalculatorState()
        XCTAssertTrue(a.atHomepage)                                             // the app opens on its own home screen
        XCTAssertEqual(a.model, .ce)
        a.open(.evo)
        XCTAssertFalse(a.atHomepage)
        XCTAssertEqual(a.model, .evo)
        XCTAssertEqual(a.screen, .iconHome)
        a.atHomepage = true                                                     // the grid button goes back
        a.open(.ce)
        XCTAssertFalse(a.atHomepage)
        XCTAssertEqual(a.model, .ce)
        XCTAssertEqual(a.screen, .home)
        a.atHomepage = true
        a.open(.ce)                                                             // reopening the same one keeps it
        XCTAssertEqual(a.model, .ce)
        XCTAssertFalse(a.atHomepage)
        XCTAssertEqual(PlannedModel.all.count, 6)
        XCTAssertEqual(PlannedModel.all.map(\.brand).first, "Eighty4 30Xa")
    }

    func testSwitchingBackToCE() {
        s.model = .ce
        XCTAssertEqual(s.screen, .home)
        XCTAssertEqual(s.shell, .black)
        XCTAssertFalse(s.store.evo)
        XCTAssertEqual(s.store.numbers["Xmax"], 10)
        keys([.second, .plus])
        XCTAssertEqual(s.screen, .menu(.mem))
    }
}
