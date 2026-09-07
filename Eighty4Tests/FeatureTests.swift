import XCTest
@testable import Eighty4

/// v0.3.0 features: solver, graph modes, sequences, stat tests, programs, MEM, new functions.
final class FeatureTests: XCTestCase {
    private var s: CalculatorState!

    override func setUp() {
        VariableStore.persistenceEnabled = false
        s = CalculatorState()
    }

    private func keys(_ k: [KeyID]) { k.forEach { s.press($0) } }
    private func eval(_ t: String) throws -> String {
        ResultFormatter.format(try Evaluator.evaluate(t, ctx: EvalContext(store: s.store)), store: s.store)
    }

    func testMixedNumbersStringsAndNewFunctions() throws {
        XCTAssertEqual(try eval("1_1/2"), "3/2")
        s.store.options["fraction"] = 1
        XCTAssertEqual(try eval("1_1/2"), "1_1/2")
        XCTAssertEqual(try eval("\"AB\"→Str1"), "AB")
        XCTAssertEqual(try eval("Str1+\"C\""), "ABC")
        XCTAssertEqual(try eval("length(Str1)"), "2")
        XCTAssertEqual(try eval("[[1,2][3,4]]→[A]"), "[[1 2]\n [3 4]]")
        XCTAssertEqual(try eval("rowSwap([A],1,2)"), "[[3 4]\n [1 2]]")
        XCTAssertEqual(try eval("*row(2,[A],1)"), "[[2 4]\n [3 4]]")
        XCTAssertEqual(try eval("Matr▶list([A],L₁,L₂)"), "Done")
        XCTAssertEqual(s.store.lists["L2"], [2, 4])
        XCTAssertEqual(try eval("Fill(7,L₁)"), "Done")
        XCTAssertEqual(s.store.lists["L1"], [7, 7])
        XCTAssertEqual(try eval("List▶matr(L₁,L₂,[B])"), "Done")
        XCTAssertEqual(s.store.matrices["B"], [[7, 2], [7, 4]])
        XCTAssertEqual(try eval("Pxl-On(10,20)"), "Done")
        XCTAssertEqual(try eval("pxl-Test(10,20)"), "1")
        XCTAssertEqual(try eval("StorePic 1"), "Done")
        XCTAssertEqual(s.store.pics[1]?.count, 1)
        XCTAssertEqual(try eval("ShadeNorm(⁻1,1)").prefix(5), ".6826")
    }

    func testSequences() throws {
        s.store.funcs["u"] = "u(n−1)+2"
        s.store.funcs["u(nMin)"] = "1"
        XCTAssertEqual(try eval("u(5)"), "9")
        s.store.funcs["v"] = "n²"
        XCTAssertEqual(try eval("v(4)"), "16")
        s.store.funcs["w"] = "w(n−1)+w(n−2)"
        s.store.funcs["w(nMin)"] = "{1,1}"
        XCTAssertEqual(try eval("w(7)"), "13")
    }

    func testSolver() {
        keys([.math, .up, .enter])                             // MATH B:Solver… (last item)
        XCTAssertEqual(s.screen, .solver)
        keys([.xtn, .square, .minus, .four, .enter])          // eqn: X²−4 = 0
        XCTAssertEqual(s.solverStage, 1)
        keys([.one, .enter, .up, .alpha, .enter])               // X=1 guess, SOLVE
        XCTAssertEqual(s.store.reals["X"] ?? 0, 2, accuracy: 1e-6)
        XCTAssertEqual(s.solverSolved, "X")
    }

    func testParametricPolarAndSequenceGraphs() {
        keys([.mode, .down, .down, .down, .down, .right, .enter, .second, .mode])
        XCTAssertEqual(s.store.graphType, .parametric)
        keys([.yEquals])
        XCTAssertEqual(s.yKeys.first, "X1T")
        keys([.three, .cos, .xtn, .rparen, .down, .three, .sin, .xtn, .rparen, .zoom, .six])
        XCTAssertEqual(s.store.funcs["X1T"], "3cos(T)")
        XCTAssertEqual(s.screen, .graph)
        XCTAssertEqual(s.graphSamples.count, 1)
        XCTAssertGreaterThan(s.graphSamples[1]?.count ?? 0, 40)
        keys([.trace, .right, .right])
        XCTAssertEqual(s.traceX, 2 * Double.pi / 24, accuracy: 1e-9)
        keys([.window])
        XCTAssertEqual(Editors.def(.window, store: s.store).rows.count, 9)

        s.store.options["graph"] = 2
        s.store.funcs["r1"] = "2"
        s.openGraph(.view)
        XCTAssertNotNil(s.graphSamples[1]?.first ?? nil)

        s.store.options["graph"] = 3
        s.store.funcs["u"] = "2n"
        s.openGraph(.view)
        XCTAssertEqual(s.graphSamples[1]?.count, 10)
        XCTAssertEqual(TableColumns.columns(s.store).first?.label, "u(n)")
    }

    func testZBoxAndZoomFactors() {
        keys([.yEquals, .xtn, .zoom, .six, .zoom, .one])      // ZBox
        XCTAssertEqual(s.graphMode, .zbox)
        keys([.enter, .right, .right, .right, .down, .down, .enter])
        XCTAssertEqual(s.graphMode, .view)
        XCTAssertLessThan(s.store.numbers["Xmax"]!, 10)
        keys([.zoom, .right, .four, .two, .enter])            // SetFactors: XFact = 2
        XCTAssertEqual(s.store.numbers["XFact"], 2)
    }

    func testStatTests() {
        keys([.stat, .left, .enter])                          // TESTS 1:Z-Test
        XCTAssertEqual(s.screen, .editor(.statTest(.zTest)))
        keys([.right, .enter])                                // Inpt: Stats
        keys([.five, .enter, .two, .enter, .five, .dot, .eight, .enter, .two, .zero, .enter, .down, .enter])
        guard case .message(let lines) = s.screen else { return XCTFail("expected results") }
        XCTAssertEqual(lines.first, "Z-Test")
        XCTAssertEqual(s.store.stats["z"] ?? 0, 1.788854382, accuracy: 1e-6)
        XCTAssertEqual(s.store.stats["p"] ?? 0, 0.0736, accuracy: 1e-3)

        s.store.lists["L1"] = [1, 2, 3, 4, 5]
        s.store.lists["L2"] = [2, 4, 5, 4, 5]
        let r = try? StatTest.linRegTTest.run(store: s.store)
        XCTAssertNotNil(r)
        XCTAssertEqual(s.store.stats["b"] ?? 0, 0.6, accuracy: 1e-9)
        XCTAssertEqual(try? eval("ANOVA({1,2,3},{2,3,4},{5,6,7})"), "Done")
        XCTAssertEqual(s.store.stats["F"] ?? 0, 13, accuracy: 1e-6)
    }

    func testRegressions() throws {
        let x: [Double] = [0, 1, 2, 3, 4, 5, 6]
        let y = x.map { 10 / (1 + 4 * exp(-1.2 * $0)) }
        let l = try Stats.logisticReg(x, y)
        XCTAssertEqual(l.c, 10, accuracy: 0.05)
        XCTAssertEqual(l.b, 1.2, accuracy: 0.05)
        let sx = stride(from: 0.0, through: 6.0, by: 0.5).map { $0 }
        let sy = sx.map { 2 * sin(1.5 * $0 + 0.3) + 1 }
        let r = try Stats.sinReg(sx, sy)
        XCTAssertEqual(r.a, 2, accuracy: 0.05)
        XCTAssertEqual(r.b, 1.5, accuracy: 0.05)
        XCTAssertEqual(r.d, 1, accuracy: 0.05)
    }

    func testProgramsRunAndEdit() {
        s.store.programs["T"] = ["1→X", "Disp X+1", "For(I,1,3)", "X+I→X", "End", "If X>5", "Then", "Disp \"BIG\"", "Else", "Disp \"SMALL\"", "End", "Disp X"]
        keys([.prgm, .three, .enter])                         // EXEC 3:T (after GEODASH, TETRIS)
        XCTAssertNil(s.runner)
        let texts = s.history.map(\.text)
        XCTAssertTrue(texts.contains("2"))
        XCTAssertTrue(texts.contains("BIG"))
        XCTAssertTrue(texts.contains("7"))
        XCTAssertEqual(s.history.last?.text, "Done")

        // Input pauses the runner until ENTER.
        s.store.programs["Q"] = ["Input \"N=\",N", "Disp N×2"]
        s.entry = Array("prgmQ"); s.cursor = 5
        keys([.enter])
        XCTAssertNotNil(s.runner)
        keys([.two, .one, .enter])
        XCTAssertNil(s.runner)
        XCTAssertTrue(s.history.map(\.text).contains("42"))

        // Menu( shows a program menu and Goto follows the label.
        s.store.programs["M"] = ["Menu(\"PICK\",\"ONE\",A,\"TWO\",B)", "Lbl A", "Disp 1", "Stop", "Lbl B", "Disp 2"]
        s.entry = Array("prgmM"); s.cursor = 5
        keys([.enter])
        if case .programMenu(let title, let items) = s.screen { XCTAssertEqual(title, "PICK"); XCTAssertEqual(items, ["ONE", "TWO"]) } else { XCTFail("expected menu") }
        keys([.two])
        XCTAssertTrue(s.history.map(\.text).contains("2"))

        // Editor: NEW program, type a line, split with ENTER.
        keys([.prgm, .right, .right, .enter])
        XCTAssertEqual(s.screen, .programName)
        keys([.math, .sin, .enter])                           // alpha-lock: A E → "AE"
        XCTAssertEqual(s.screen, .confirm(.programLock("AE")))
        keys([.one])                                          // 1:No lock
        XCTAssertEqual(s.screen, .programEditor("AE"))
        keys([.one, .plus, .one, .enter, .two])
        s.commitProgramLine()
        XCTAssertEqual(s.store.programs["AE"], ["1+1", "2"])
        keys([.second, .mode])
        XCTAssertEqual(s.screen, .home)
        XCTAssertTrue(s.entry.isEmpty, "QUIT from the program editor restores the home entry")
        keys([.prgm, .three])                                 // EXEC 3: AE runs without a syntax error
        if case .error = s.screen { XCTFail("running the edited program raised an error") }
        // Home-screen Disp goes through the runner too.
        s.entry = Array("Disp 5"); s.cursor = 6
        keys([.enter])
        XCTAssertTrue(s.history.map(\.text).contains("5"))
    }

    func testMemArchiveDeleteAndGroups() {
        s.store.reals["A"] = 3
        keys([.second, .plus, .five])                          // Archive…
        XCTAssertEqual(s.screen, .varList(.archive))
        keys([.enter])
        XCTAssertTrue(s.store.archived.contains("A"))
        keys([.clear, .second, .plus, .two, .enter])          // Mem Mgmt → All
        XCTAssertEqual(s.screen, .varList(.manage("All")))
        keys([.del, .two])                                    // delete A, confirm
        XCTAssertNil(s.store.reals["A"])
        keys([.clear, .second, .plus, .eight, .enter])        // Group… Create New
        XCTAssertEqual(s.screen, .groupName)
        keys([.math, .enter])                                 // name "A"
        XCTAssertNotNil(s.store.groups["A"])
        keys([.clear, .second, .plus, .seven, .right, .enter, .two])   // Reset ARCHIVE Vars → 2:Reset
        if case .message = s.screen {} else { XCTFail("expected message after reset") }
    }

    func testAppsOpenAndRun() {
        for (i, id) in [AppID.cabriJr, .celSheet, .conics, .inequalz, .plySmlt2, .probSim, .sciTools, .transfrm, .vernier].enumerated() {
            keys([.apps])
            for _ in 0..<(3 + i) { keys([.down]) }
            keys([.enter])
            XCTAssertEqual(s.screen, .app(id), "\(id)")
            keys([.clear, .clear, .clear])
            s.game = nil; s.screen = .home
        }
        let roots = Cx.roots([1, -3, 2])
        XCTAssertEqual(roots.count, 2)
        XCTAssertEqual(roots[0].re, 1, accuracy: 1e-9)
        XCTAssertEqual(roots[1].re, 2, accuracy: 1e-9)
        let complex = Cx.roots([1, 0, 1])
        XCTAssertEqual(complex.map { abs($0.im) }, [1, 1])
        let sheet = CelSheetApp(store: s.store)
        s.store.sheet = ["A1": "2", "A2": "3", "B1": "A1×A2+sum(A1:A2)"]
        XCTAssertEqual(sheet.value("B1"), .num(11))
    }
}
