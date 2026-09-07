import XCTest
@testable import Eighty4

/// Complex arithmetic, the REAL / a+bi / re^θi modes, and the OS 5.x function additions.
final class ComplexTests: XCTestCase {
    private var store: VariableStore!

    override func setUp() {
        VariableStore.persistenceEnabled = false
        store = VariableStore()
    }

    private func eval(_ s: String) throws -> String {
        ResultFormatter.format(try Evaluator.evaluate(s, ctx: EvalContext(store: store)), store: store)
    }

    private func assertError(_ s: String, _ e: CalcError, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try eval(s), file: file, line: line) { XCTAssertEqual($0 as? CalcError, e, file: file, line: line) }
    }

    func testArithmetic() throws {
        XCTAssertEqual(try eval("i²"), "⁻1")
        XCTAssertEqual(try eval("(1+i)(1−i)"), "2")
        XCTAssertEqual(try eval("(3+2i)+(1−5i)"), "4−3i")
        XCTAssertEqual(try eval("(3+2i)(1−5i)"), "13−13i")
        XCTAssertEqual(try eval("(1+i)÷(1−i)"), "i")
        XCTAssertEqual(try eval("(1+i)^2"), "2i")
        XCTAssertEqual(try eval("(1+i)⁻¹"), ".5−.5i")
        XCTAssertEqual(try eval("2i"), "2i")
        XCTAssertEqual(try eval("⁻i"), "⁻i")
        XCTAssertEqual(try eval("e^(iπ)"), "⁻1+1.224646799ᴇ⁻16i")
        XCTAssertEqual(try eval("i=i"), "1")
        XCTAssertEqual(try eval("i≠1"), "1")
        assertError("i<1", .dataType)
        assertError("1÷(0i)", .divideByZero)
    }

    func testCmplxFunctions() throws {
        XCTAssertEqual(try eval("conj(3+4i)"), "3−4i")
        XCTAssertEqual(try eval("real(3+4i)"), "3")
        XCTAssertEqual(try eval("imag(3+4i)"), "4")
        XCTAssertEqual(try eval("abs(3+4i)"), "5")
        XCTAssertEqual(try eval("angle(i)"), "1.570796327")
        XCTAssertEqual(try eval("angle(⁻2)"), "3.141592654")
        XCTAssertEqual(try eval("√(2i)"), "1+i")
        XCTAssertEqual(try eval("ln(i)"), "1.570796327i")
        store.options["angle"] = 1
        XCTAssertEqual(try eval("angle(i)"), "90")
    }

    func testModesAndNonrealAns() throws {
        assertError("√(⁻4)", .nonrealAns)
        assertError("(⁻8)^(1÷3)", .nonrealAns)
        assertError("ln(⁻1)", .nonrealAns)
        assertError("4ˣ√⁻16", .nonrealAns)
        store.options["complex"] = 1
        XCTAssertEqual(try eval("√(⁻4)"), "2i")
        XCTAssertEqual(try eval("(⁻8)^(1÷3)"), "1+1.732050808i")
        XCTAssertEqual(try eval("ln(⁻1)"), "3.141592654i")
        XCTAssertEqual(try eval("log(⁻10)"), "1+1.364376354i")
        XCTAssertEqual(try eval("3ˣ√⁻27"), "⁻3")            // odd roots of negatives stay real
        store.options["complex"] = 2
        XCTAssertEqual(try eval("2i"), "2e^(1.570796327i)")
        XCTAssertEqual(try eval("2i▶Rect"), "2i")
        store.options["complex"] = 1
        XCTAssertEqual(try eval("2i▶Polar"), "2e^(1.570796327i)")
        XCTAssertEqual(try eval("2i"), "2i")                 // ▶Polar only applied to that one result
        XCTAssertEqual(try eval("a+bi"), "Done")
        XCTAssertEqual(store.options["complex"], 1)
        XCTAssertEqual(try eval("Real"), "Done")
        XCTAssertEqual(store.options["complex"], 0)
    }

    func testComplexVariablesAndAns() throws {
        XCTAssertEqual(try eval("2+3i→Z"), "2+3i")
        XCTAssertEqual(try eval("Z×i"), "⁻3+2i")
        XCTAssertEqual(store.complexes["Z"], [2, 3])
        XCTAssertEqual(try eval("5→Z"), "5")
        XCTAssertNil(store.complexes["Z"])
        XCTAssertEqual(try eval("Z"), "5")
        store.ans = .complex(1, 1)
        XCTAssertEqual(try eval("Ans²"), "2i")
        XCTAssertEqual(try eval("toString(1+i)"), "1+i")
        assertError("sin(i)", .dataType)
        XCTAssertEqual(try eval("{1,i}"), "{1 i}")
    }

    func testComplexLists() throws {
        XCTAssertEqual(try eval("{1+i,2}"), "{1+i 2}")
        XCTAssertEqual(try eval("{1+i,2}×i"), "{⁻1+i 2i}")
        XCTAssertEqual(try eval("{1,2}+i"), "{1+i 2+i}")
        XCTAssertEqual(try eval("{1+i,2}+{1−i,3}"), "{2 5}")           // collapses to a real list
        XCTAssertEqual(try eval("{1+i,2}²"), "{2i 4}")
        XCTAssertEqual(try eval("⁻{1+i,2}"), "{⁻1−i ⁻2}")
        XCTAssertEqual(try eval("conj({1+i,2})"), "{1−i 2}")
        XCTAssertEqual(try eval("real({1+2i,3})"), "{1 3}")
        XCTAssertEqual(try eval("imag({1+2i,3})"), "{2 0}")
        XCTAssertEqual(try eval("abs({3+4i,⁻2})"), "{5 2}")
        XCTAssertEqual(try eval("sum({1+i,2−i})"), "3")
        XCTAssertEqual(try eval("prod({1+i,1−i})"), "2")
        XCTAssertEqual(try eval("mean({2i,4})"), "2+i")
        XCTAssertEqual(try eval("dim({i,1,2})"), "3")
        XCTAssertEqual(try eval("cumSum({i,1})"), "{i 1+i}")
        XCTAssertEqual(try eval("augment({1},{i})"), "{1 i}")
        XCTAssertEqual(try eval("{1+i,2}→L₁"), "{1+i 2}")
        XCTAssertEqual(try eval("L₁×2"), "{2+2i 4}")
        XCTAssertEqual(store.complexLists["L1"], [[1, 1], [2, 0]])
        XCTAssertEqual(try eval("{5}→L₁"), "{5}")
        XCTAssertNil(store.complexLists["L1"])
        assertError("{1+i,2}+{1,2,3}", .dimMismatch)
        assertError("SortA({i,1})", .dataType)
        assertError("{1+i}<{1}", .dataType)
    }

    func testOs5Functions() throws {
        XCTAssertEqual(try eval("toString(1÷4)"), ".25")
        XCTAssertEqual(try eval("eval(\"2+3\")"), "5")
        XCTAssertEqual(try eval("length(eval(\"2+3\"))"), "1")
        XCTAssertEqual(try eval("invBinom(.5,10,.5)"), "5")
        XCTAssertEqual(try eval("invBinom(.95,20,.3)"), "9")
        XCTAssertEqual(try eval("50%"), ".5")
    }
}
