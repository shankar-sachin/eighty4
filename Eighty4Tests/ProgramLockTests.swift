import XCTest
@testable import Eighty4

/// PRGM NEW asks "Program Lock?"; locked programs run but EDIT offers to unlock first.
final class ProgramLockTests: XCTestCase {
    private var s: CalculatorState!

    override func setUp() {
        VariableStore.persistenceEnabled = false
        s = CalculatorState()
    }

    private func keys(_ k: [KeyID]) { k.forEach { s.press($0) } }

    func testNewProgramAsksForLock() {
        keys([.prgm, .right, .right, .enter, .math, .apps, .enter])   // NEW → "AB" → ENTER
        XCTAssertEqual(s.screen, .confirm(.programLock("AB")))
        keys([.two])                                                   // 2:Yes
        XCTAssertTrue(s.store.lockedPrograms.contains("AB"))
        XCTAssertEqual(s.screen, .programEditor("AB"))                 // still opens so it can be written
        keys([.prgm, .right, .three, .five, .enter, .second, .mode])   // :Disp 5, QUIT
        XCTAssertEqual(s.store.programs["AB"], ["Disp 5", ""])

        keys([.prgm, .right, .enter])                                  // EDIT → AB [LOCKED]
        XCTAssertEqual(s.screen, .confirm(.programUnlock("AB")))
        keys([.one])                                                   // keep locked
        XCTAssertEqual(s.screen, .home)
        XCTAssertTrue(s.store.lockedPrograms.contains("AB"))

        keys([.prgm, .three, .enter])                                  // EXEC 3:AB (after GEODASH, TETRIS) still runs it
        XCTAssertTrue(s.history.map(\.text).contains("5"))

        keys([.prgm, .right, .enter, .two])                            // EDIT → unlock and edit
        XCTAssertFalse(s.store.lockedPrograms.contains("AB"))
        XCTAssertEqual(s.screen, .programEditor("AB"))
    }

    func testDecliningLockLeavesProgramEditable() {
        keys([.prgm, .right, .right, .enter, .math, .enter, .one])     // NEW "A", 1:No
        XCTAssertFalse(s.store.lockedPrograms.contains("A"))
        XCTAssertEqual(s.screen, .programEditor("A"))
        keys([.second, .mode, .prgm, .right, .enter])
        XCTAssertEqual(s.screen, .programEditor("A"))
    }
}
