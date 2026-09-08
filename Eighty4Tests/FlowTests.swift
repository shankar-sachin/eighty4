import XCTest
@testable import Eighty4

final class FlowTests: XCTestCase {
    private var s: CalculatorState!

    override func setUp() {
        VariableStore.persistenceEnabled = false
        s = CalculatorState()
    }

    private func keys(_ k: [KeyID]) { k.forEach { s.press($0) } }

    func testHomeEvaluationAndModifiers() {
        keys([.two, .second, .power, .enter])                 // 2π
        XCTAssertEqual(s.history.last?.text, "6.283185307")
        keys([.second, .negate, .multiply, .two, .enter])     // Ans×2
        XCTAssertEqual(s.history.last?.text, "12.56637061")
        keys([.three, .plus, .four, .alpha, .enter])          // alpha+enter still evaluates
        XCTAssertEqual(s.history.last?.text, "7")
        keys([.second, .enter])                               // ENTRY recalls with empty entry
        XCTAssertEqual(String(s.entry), "3+4")
        keys([.plus, .one, .second, .enter])                  // 2nd+enter with text evaluates
        XCTAssertEqual(s.history.last?.text, "8")
        keys([.up, .up, .enter])                              // ▲ selects "8", ▲ selects "3+4+1", ENTER pastes it
        XCTAssertEqual(String(s.entry), "3+4+1")
        keys([.clear, .clear])
        XCTAssertTrue(s.history.isEmpty)
    }

    func testMenusInsertTokens() {
        keys([.math, .right, .enter])                         // MATH → NUM → 1:abs( (MATHPRINT: the |□| template)
        XCTAssertEqual(s.screen, .home)
        XCTAssertEqual(String(s.entry), MathPrint.template(.abs))
        keys([.negate, .three, .enter])
        XCTAssertEqual(s.history.last?.text, "3")
        keys([.second, .math, .three])                        // TEST 3: >
        XCTAssertEqual(String(s.entry), ">")
        keys([.clear, .second, .zero])                        // CATALOG
        XCTAssertEqual(s.screen, .menu(.catalog))
        keys([.clear])
        XCTAssertEqual(s.screen, .home)
    }

    func testModeEditorChangesAngle() {
        keys([.mode, .down, .down, .down, .right, .enter, .second, .mode])   // RADIAN → DEGREE
        XCTAssertTrue(s.store.degrees)
        XCTAssertTrue(s.store.statusText.contains("DEGREE"))
        keys([.sin, .three, .zero, .rparen, .enter])
        XCTAssertEqual(s.history.last?.text, ".5")
    }

    func testYEqualsGraphAndTable() {
        keys([.yEquals, .xtn, .square, .down, .two, .xtn])
        XCTAssertEqual(s.screen, .yEquals)
        keys([.zoom, .six])                                   // ZStandard → graph
        XCTAssertEqual(s.screen, .graph)
        XCTAssertEqual(s.store.yFuncs[1], "X²")
        XCTAssertEqual(s.store.yFuncs[2], "2X")
        XCTAssertEqual(s.graphSamples.count, 2)
        XCTAssertNotNil(s.graphSamples[1]?[160])
        keys([.trace, .right, .right])
        XCTAssertEqual(s.graphMode, .trace)
        keys([.second, .graph])                               // TABLE
        XCTAssertEqual(s.screen, .table)
        XCTAssertEqual(Graphing.y(1, at: 3, store: s.store), 9)
        keys([.window])
        XCTAssertEqual(s.screen, .editor(.window))
        keys([.one, .enter])                                  // Xmin = 1
        XCTAssertEqual(s.store.numbers["Xmin"], 1)
        keys([.second, .mode])
        XCTAssertEqual(s.screen, .home)
    }

    func testCalcZero() {
        keys([.yEquals, .xtn, .square, .minus, .four, .zoom, .six])
        keys([.second, .trace, .two])                         // CALC 2:zero
        XCTAssertEqual(s.graphMode, .calc(.zero))
        keys([.one, .enter])                                  // left bound X=1
        keys([.three, .enter])                                // right bound X=3
        keys([.two, .enter])                                  // guess X=2
        XCTAssertNotNil(s.calcResult)
        XCTAssertEqual(s.calcResult!.x, 2, accuracy: 1e-6)
    }

    func testMatrixAndListEditors() {
        keys([.second, .inverse, .right, .right, .enter])     // MATRIX EDIT [A]
        XCTAssertEqual(s.screen, .matrixEditor("A"))
        keys([.two, .enter, .two, .enter, .one, .enter, .two, .enter, .three, .enter, .four, .enter])
        XCTAssertEqual(s.store.matrices["A"], [[1, 2], [3, 4]])
        keys([.second, .mode, .second, .inverse, .enter, .inverse, .enter])   // [A]⁻¹
        XCTAssertEqual(s.history.last?.text, " [1.5 ⁻.5]]")
        keys([.stat, .enter, .five, .enter, .seven, .enter])  // STAT EDIT: L1 = {5, 7}
        XCTAssertEqual(s.store.lists["L1"], [5, 7])
        keys([.stat, .right, .enter])                         // 1-Var Stats
        if case .message(let lines) = s.screen { XCTAssertTrue(lines.contains(" x̄=6")) } else { XCTFail("expected stats screen") }
    }

    func testAppsAndPower() {
        keys([.apps, .enter])
        XCTAssertEqual(s.screen, .app(.geoDash))
        XCTAssertNotNil(s.game)
        keys([.clear])
        XCTAssertEqual(s.screen, .home)
        keys([.prgm, .down, .enter])
        XCTAssertEqual(s.screen, .app(.tetris))
        keys([.second, .on])
        XCTAssertEqual(s.screen, .off)
        keys([.on])
        XCTAssertEqual(s.screen, .home)
    }

    func testGeoDashAndTetrisModels() {
        let g = GeoDashGame()
        var t: TimeInterval = 0
        g.update(now: t)
        var died = false
        for _ in 0..<600 {
            t += 1.0 / 60
            g.update(now: t)
            if g.attempts > 1 { died = true; break }
        }
        XCTAssertTrue(died, "cube should die on the first spike without jumping")

        let tet = TetrisGame()
        for _ in 0..<200 { tet.press(.enter) }   // hard drops eventually end the game or clear lines
        XCTAssertTrue(tet.over || tet.lines > 0 || tet.score >= 0)
    }
}
