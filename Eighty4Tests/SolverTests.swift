import XCTest
@testable import Eighty4

/// The equation solver: `=` equations, root finding, bounds, and both models' solve keys.
final class SolverTests: XCTestCase {
    private var s: CalculatorState!

    override func setUp() {
        VariableStore.persistenceEnabled = false
        s = CalculatorState()
    }

    private func keys(_ k: [KeyID]) { k.forEach { s.press($0) } }

    private func solve(_ eqn: String, for name: String, guess: Double = 0,
                       lo: Double = -Solver.defaultBound, hi: Double = Solver.defaultBound) throws -> Double {
        try Solver.solve(eqn, for: name, guess: guess, lo: lo, hi: hi, store: s.store)
    }

    // MARK: - Equations written with "="

    func testResidualSplit() {
        XCTAssertEqual(Solver.residual("2X+3=11"), "(2X+3)−(11)")
        XCTAssertEqual(Solver.residual("X²−4"), "X²−4")                          // an expression is left alone
        XCTAssertEqual(Solver.residual("piecewise(1,X=2,3)"), "piecewise(1,X=2,3)")  // only a top-level =
        XCTAssertEqual(Solver.residual("=4"), "=4")                              // nothing on the left
        XCTAssertTrue(Solver.isEquation("A=B"))
        XCTAssertFalse(Solver.isEquation("A−B"))
        XCTAssertEqual(Solver.title("X²−4"), "X²−4=0")
        XCTAssertEqual(Solver.title("2X=8"), "2X=8")
        XCTAssertEqual(Solver.variables(in: "2X+3=Y"), ["X", "Y"])
    }

    func testSolvesEquationsAndExpressions() throws {
        // The bug: "=" used to evaluate as a true/false test, so the solver returned the guess untouched.
        XCTAssertEqual(try solve("2X+3=11", for: "X", guess: 0), 4, accuracy: 1e-9)
        XCTAssertEqual(try solve("2X+3=11", for: "X", guess: 500), 4, accuracy: 1e-9)
        XCTAssertEqual(try solve("X²−4", for: "X", guess: 1), 2, accuracy: 1e-9)
        XCTAssertEqual(try solve("X²=4", for: "X", guess: -3), -2, accuracy: 1e-9)
        // The Evo's own example: 2ˣ=X² has roots at 2 and 4.
        XCTAssertEqual(try solve("2^X=X²", for: "X", guess: 1.5), 2, accuracy: 1e-6)
        XCTAssertEqual(try solve("2^X=X²", for: "X", guess: 5), 4, accuracy: 1e-6)
        // Other variables keep their stored values.
        s.store.reals["A"] = 3
        s.store.reals["B"] = 12
        XCTAssertEqual(try solve("A×X=B", for: "X", guess: 0), 4, accuracy: 1e-9)
        s.store.reals["X"] = 4
        XCTAssertEqual(try solve("A×X=B", for: "A", guess: 1), 3, accuracy: 1e-9)
        // Transcendental equations need the bracketing fallback, not Newton alone.
        XCTAssertEqual(try solve("sin(X)=0", for: "X", guess: 3), Double.pi, accuracy: 1e-6)
        XCTAssertEqual(try solve("e^(X)=5", for: "X", guess: 0), log(5), accuracy: 1e-6)
    }

    func testRootsThatDoNotExist() {
        // No real root anywhere: ERR:NO SIGN CHNG rather than a made-up answer.
        XCTAssertThrowsError(try solve("X²+1", for: "X", guess: 0)) { XCTAssertEqual($0 as? CalcError, .noSignChange) }
        // A sign change across a pole is not a root.
        XCTAssertThrowsError(try solve("1÷(X−2)=0", for: "X", guess: 1, lo: 0, hi: 4)) {
            XCTAssertEqual($0 as? CalcError, .noSignChange)
        }
        // A broken equation reports the real error.
        XCTAssertThrowsError(try solve("X²+", for: "X", guess: 0)) { XCTAssertEqual($0 as? CalcError, .syntax) }
    }

    func testBoundsLimitTheSearch() throws {
        // X²−4 has roots at ±2; the bounds pick which one comes back.
        XCTAssertEqual(try solve("X²=4", for: "X", guess: 0, lo: 0, hi: 10), 2, accuracy: 1e-9)
        XCTAssertEqual(try solve("X²=4", for: "X", guess: 0, lo: -10, hi: 0), -2, accuracy: 1e-9)
        XCTAssertThrowsError(try solve("X²=4", for: "X", guess: 0, lo: -1, hi: 1))
    }

    // MARK: - The solver screen

    func testSolverScreenOnTheCE() {
        keys([.math, .up, .enter])                                              // MATH B:Solver…
        XCTAssertEqual(s.screen, .solver)
        keys([.two, .xtn, .plus, .three, .second, .math, .enter, .one, .one, .enter])   // 2X+3=11
        XCTAssertEqual(s.store.solverEqn, "2X+3=11")
        XCTAssertEqual(s.solverStage, 1)
        XCTAssertEqual(s.solverVariables, ["X"])
        keys([.five, .enter])                                                   // guess X=5
        XCTAssertEqual(s.store.reals["X"] ?? 0, 5, accuracy: 1e-9)
        keys([.up, .alpha, .enter])                                             // alpha+ENTER solves
        XCTAssertEqual(s.store.reals["X"] ?? 0, 4, accuracy: 1e-6)
        XCTAssertEqual(s.solverSolved, "X")
        XCTAssertEqual(Solver.residualValue(s.store.solverEqn, store: s.store) ?? 1, 0, accuracy: 1e-6)
        // ▲ from the first row goes back to the equation for editing.
        keys([.up])
        XCTAssertEqual(s.solverStage, 0)
        XCTAssertEqual(String(s.entry), "2X+3=11")
    }

    func testBoundRowIsEditable() {
        keys([.math, .up, .enter])
        keys([.xtn, .square, .minus, .four, .enter])                            // X²−4
        XCTAssertEqual(s.solverBounds.lo, -Solver.defaultBound)
        keys([.down])                                                           // onto the bound row
        XCTAssertEqual(s.solverRow, 1)
        XCTAssertEqual(s.solverRowText(1), "{⁻1ᴇ99,1ᴇ99}")
        keys([.second, .lparen, .negate, .one, .zero, .comma, .zero, .second, .rparen, .enter])   // {⁻10,0}
        XCTAssertEqual(s.solverBounds.lo, -10)
        XCTAssertEqual(s.solverBounds.hi, 0)
        keys([.up, .one, .alpha, .enter])                                       // guess 1, solve inside the bounds
        XCTAssertEqual(s.store.reals["X"] ?? 0, -2, accuracy: 1e-6)
    }

    func testEvoNumericSolverSolvesOnEnter() {
        s.model = .evo
        s.iconIndex = HomeIcon.numericSolver.rawValue
        keys([.enter])
        XCTAssertEqual(s.screen, .solver)
        keys([.two, .expTemplate, .xtn, .right, .second, .math, .enter, .xtn, .square, .enter])   // 2^X=X²
        XCTAssertEqual(s.store.solverEqn, "2^X=X²")
        XCTAssertEqual(s.solverStage, 1)
        keys([.five, .enter])                                                   // typing then ENTER stores the guess
        XCTAssertEqual(s.store.reals["X"] ?? 0, 5, accuracy: 1e-9)
        keys([.up, .enter])                                                     // ENTER alone solves on the Evo
        XCTAssertEqual(s.store.reals["X"] ?? 0, 4, accuracy: 1e-6)
        XCTAssertEqual(s.solverSolved, "X")
    }
}
