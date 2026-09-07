import XCTest
@testable import Eighty4

/// Token-wise entry editing and hardware-keyboard input.
final class KeyboardTests: XCTestCase {
    private var s: CalculatorState!

    override func setUp() {
        VariableStore.persistenceEnabled = false
        s = CalculatorState()
    }

    private func keys(_ k: [KeyID]) { k.forEach { s.press($0) } }
    private func type(_ text: String) { text.forEach { s.pressHardware(.char($0)) } }

    func testDelRemovesWholeFunctionToken() {
        keys([.two, .sin, .three, .rparen])              // 2sin(3)
        XCTAssertEqual(String(s.entry), "2sin(3)")
        keys([.left, .left, .left])                      // cursor lands on "sin("
        XCTAssertEqual(s.cursor, 1)
        keys([.del])
        XCTAssertEqual(String(s.entry), "23)")
        XCTAssertEqual(s.cursor, 1)

        keys([.clear, .second, .square, .second, .one, .del])   // √(L₁ then DEL at the end
        XCTAssertEqual(String(s.entry), "√(")
        keys([.del])
        XCTAssertTrue(s.entry.isEmpty)
    }

    func testCursorSkipsTokensAndOverwriteReplacesToken() {
        keys([.sin, .one])                               // sin(1
        keys([.left, .left])
        XCTAssertEqual(s.cursor, 0)
        keys([.right])
        XCTAssertEqual(s.cursor, 4)
        keys([.left, .cos])                              // overwrite sin( with cos(
        XCTAssertEqual(String(s.entry), "cos(1")
        keys([.clear, .two, .plus, .three, .left, .left, .left, .sin])   // overwrite "2" with sin(
        XCTAssertEqual(String(s.entry), "sin(+3")
    }

    func testDigitsDoNotFuseIntoTokens() {
        keys([.one, .zero, .power, .lparen, .del])
        XCTAssertEqual(String(s.entry), "10^")
    }

    func testTokenDeleteInYEquals() {
        keys([.yEquals, .xtn, .square, .plus, .second, .square, .xtn, .rparen])   // X²+√(X)
        keys([.left, .left, .left, .del])
        XCTAssertEqual(String(s.entry), "X²+X)")
    }

    func testHardwareTypingEvaluates() {
        type("2*(3+4)")
        s.pressHardware(.enter)
        XCTAssertEqual(s.history.last?.text, "14")
        type("x")                                        // letters go through alpha
        XCTAssertEqual(String(s.entry), "X")
        XCTAssertEqual(s.modifier, .none)
        s.pressHardware(.backspace)
        XCTAssertTrue(s.entry.isEmpty)
        type("π")
        XCTAssertEqual(String(s.entry), "π")
        s.pressHardware(.escape)
        type("(1+i)^2+e^0")                              // lowercase i / e are the constants, uppercase are variables
        XCTAssertEqual(String(s.entry), "(1+i)^2+e^0")
        s.pressHardware(.enter)
        XCTAssertEqual(s.history.last?.text, "1+2i")
        type("I+E")
        XCTAssertEqual(String(s.entry), "I+E")
        s.pressHardware(.escape)
        XCTAssertTrue(s.entry.isEmpty)
        XCTAssertFalse(s.pressHardware(.char("@")))
    }

    func testHardwareBackspaceRemovesTokenBeforeCursor() {
        type("12+3")
        s.pressHardware(.left)
        s.pressHardware(.left)                           // before "+"
        s.pressHardware(.backspace)                      // removes "2"
        XCTAssertEqual(String(s.entry), "1+3")
        XCTAssertEqual(s.cursor, 1)
        s.pressHardware(.forwardDelete)                  // removes "+"
        XCTAssertEqual(String(s.entry), "13")
    }

    func testHistoryScrollBackPastesWithEnter() {
        keys([.two, .plus, .three, .enter, .four, .multiply, .five, .enter])
        XCTAssertNil(s.historySelection)
        keys([.up])                                       // newest answer "20"
        XCTAssertNotNil(s.historySelection)
        XCTAssertEqual(s.history.last?.group, s.historySelection)
        keys([.up, .up])                                  // "4×5", then "5"
        keys([.enter])
        XCTAssertEqual(String(s.entry), "5")
        XCTAssertNil(s.historySelection)
        keys([.up, .up, .up, .up, .up, .up])              // top of the list stays selected
        XCTAssertEqual(s.historySelection, s.history.first?.group)
        keys([.down, .down, .down, .down])                // past the newest → back to the entry line
        XCTAssertNil(s.historySelection)
        XCTAssertEqual(s.homeScroll, 0)
        XCTAssertEqual(String(s.entry), "5")
        keys([.up, .plus])                                // any other key drops the highlight and is applied
        XCTAssertNil(s.historySelection)
        XCTAssertEqual(String(s.entry), "5+")
    }

    func testDelRemovesSelectedHistoryItem() {
        keys([.two, .plus, .three, .enter, .four, .multiply, .five, .enter])
        XCTAssertEqual(s.history.count, 4)
        keys([.up, .up])                                  // "20", then "4×5"
        keys([.del])                                      // removes the whole 4×5 / 20 pair
        XCTAssertEqual(s.history.map(\.text), ["2+3", "5"])
        XCTAssertNil(s.historySelection)                  // nothing newer left → back on the entry line
        keys([.six, .enter])
        keys([.up, .up, .up])                             // "6", "5", then "2+3"
        keys([.clear])                                    // CLEAR removes the 2+3 / 5 pair too
        XCTAssertEqual(s.history.map(\.text), ["6", "6"])
        XCTAssertEqual(s.historySelection, s.history.first?.group)   // highlight moved to the next newer item
        keys([.up, .del])                                 // answer "6" selected → same pair goes
        XCTAssertTrue(s.history.isEmpty)
        keys([.one, .enter])
        s.pressHardware(.up)                              // physical arrow + Backspace do the same
        s.pressHardware(.backspace)
        XCTAssertTrue(s.history.isEmpty)
    }

    func testClearAndPairDeleteResetAns() {
        keys([.eight, .eight, .plus, .one, .enter])                    // 89
        keys([.second, .negate, .plus, .one, .enter])                   // Ans+1 = 90
        XCTAssertEqual(s.history.last?.text, "90")
        keys([.up, .del])                                               // delete the Ans+1 / 90 pair
        XCTAssertEqual(s.store.ans, .num(89))
        keys([.second, .negate, .multiply, .two, .enter])               // Ans×2 = 178
        XCTAssertEqual(s.history.last?.text, "178")
        keys([.clear])                                                  // wipe the screen → Ans is 0 again
        XCTAssertTrue(s.history.isEmpty)
        XCTAssertEqual(s.store.ans, .num(0))
        keys([.second, .negate, .plus, .one, .enter])
        XCTAssertEqual(s.history.last?.text, "1")
    }

    func testHistoryScrollsLongOutput() {
        for _ in 0..<8 { keys([.one, .enter]) }          // 16 history lines
        keys([.up])
        XCTAssertEqual(s.homeScroll, 0)
        for _ in 0..<15 { keys([.up]) }
        XCTAssertEqual(s.historySelection, s.history.first?.group)
        XCTAssertGreaterThan(s.homeScroll, 0)
        XCTAssertEqual(s.displayLines.first?.group, s.history.first?.group)
        keys([.enter])
        XCTAssertEqual(s.homeScroll, 0)
        XCTAssertEqual(String(s.entry), "1")
    }

    func testHardwareSymbolsInsertTokens() {
        type("5!")
        s.pressHardware(.enter)
        XCTAssertEqual(s.history.last?.text, "120")
        type("50%")
        s.pressHardware(.enter)
        XCTAssertEqual(s.history.last?.text, ".5")
        type("3>2")
        s.pressHardware(.enter)
        XCTAssertEqual(s.history.last?.text, "1")
        type("2=2")
        XCTAssertEqual(String(s.entry), "2=2")
        s.pressHardware(.escape)
        type("1≤")
        XCTAssertEqual(String(s.entry), "1≤")
    }

    func testTypedFunctionNamesBecomeTokens() {
        type("2sin(3)")
        XCTAssertEqual(String(s.entry), "2sin(3)")
        s.pressHardware(.enter)
        XCTAssertEqual(s.history.last?.text, ".2822400161")
        type("randint(1,1)")                             // case-insensitive match → randInt(
        XCTAssertEqual(String(s.entry), "randInt(1,1)")
        s.pressHardware(.escape)
        type("2x(3)")                                    // single letters stay variables
        XCTAssertEqual(String(s.entry), "2X(3)")
        s.pressHardware(.escape)
        type("ab(")                                      // not a function → plain letters
        XCTAssertEqual(String(s.entry), "AB(")
        s.pressHardware(.escape)
        type("si")
        keys([.left])                                    // moving the cursor breaks the word; N overwrites I
        type("n(")
        XCTAssertEqual(String(s.entry), "SN(")
    }

    func testHardwareFunctionKeysAndArrows() {
        s.pressHardware(.function(1))
        XCTAssertEqual(s.screen, .yEquals)
        s.pressHardware(.down)
        XCTAssertEqual(s.yRow, 1)
        s.pressHardware(.escape)
        keys([.second, .mode])
        XCTAssertEqual(s.screen, .home)
    }
}
