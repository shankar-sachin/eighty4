import XCTest
@testable import Eighty4

final class EngineTests: XCTestCase {
    private func eval(_ s: String, ans: Double = 0) throws -> String {
        ResultFormatter.format(try Evaluator.evaluate(s, ans: ans))
    }

    func testArithmeticAndPrecedence() throws {
        XCTAssertEqual(try eval("2+3×4"), "14")
        XCTAssertEqual(try eval("2^3^2"), "512")
        XCTAssertEqual(try eval("⁻2²"), "⁻4")
        XCTAssertEqual(try eval("1÷3"), ".3333333333")
        XCTAssertEqual(try eval("(2+3)(4)"), "20")
        XCTAssertEqual(try eval("5⁻¹"), ".2")
        XCTAssertEqual(try eval("1ᴇ3×2"), "2000")
        XCTAssertEqual(try eval("10^(15)"), "1ᴇ15")
        XCTAssertEqual(try eval("0.1+0.2"), ".3")
    }

    func testFunctionsAndConstants() throws {
        XCTAssertEqual(try eval("√(2)"), "1.414213562")
        XCTAssertEqual(try eval("sin(π÷2)"), "1")
        XCTAssertEqual(try eval("sin(π÷2"), "1")   // missing close paren is allowed
        XCTAssertEqual(try eval("2π"), "6.283185307")
        XCTAssertEqual(try eval("Ans+1", ans: 5), "6")
        XCTAssertEqual(try eval("e^(1)"), "2.718281828")
        XCTAssertEqual(try eval("log(1000)"), "3")
        XCTAssertEqual(try eval("cos⁻¹(1)"), "0")
    }

    func testErrors() {
        XCTAssertThrowsError(try eval("1÷0")) { XCTAssertEqual($0 as? CalcError, .divideByZero) }
        XCTAssertThrowsError(try eval("√(⁻1)")) { XCTAssertEqual($0 as? CalcError, .domain) }
        XCTAssertThrowsError(try eval("sin⁻¹(2)")) { XCTAssertEqual($0 as? CalcError, .domain) }
        XCTAssertThrowsError(try eval("2+")) { XCTAssertEqual($0 as? CalcError, .syntax) }
        XCTAssertThrowsError(try eval("2⁻3")) { XCTAssertEqual($0 as? CalcError, .syntax) }
    }

    func testKeyHandlerFlow() {
        let state = CalculatorState()
        state.press(.two)
        state.press(.second); state.press(.power)   // π
        state.press(.enter)
        XCTAssertEqual(state.history.last?.text, "6.283185307")
        state.press(.second); state.press(.negate)  // Ans
        state.press(.multiply); state.press(.two); state.press(.enter)
        XCTAssertEqual(state.history.last?.text, "12.56637061")
        state.press(.graph)
        XCTAssertEqual(state.screen, .comingSoon)
        state.press(.clear)
        XCTAssertEqual(state.screen, .home)
        state.press(.second); state.press(.on)
        XCTAssertEqual(state.screen, .off)
        state.press(.on)
        XCTAssertEqual(state.screen, .home)
    }
}
