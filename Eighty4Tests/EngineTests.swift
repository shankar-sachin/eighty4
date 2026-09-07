import XCTest
@testable import Eighty4

final class EngineTests: XCTestCase {
    private var store: VariableStore!

    override func setUp() {
        VariableStore.persistenceEnabled = false
        store = VariableStore()
    }

    private func eval(_ s: String) throws -> String {
        ResultFormatter.format(try Evaluator.evaluate(s, ctx: EvalContext(store: store)), store: store)
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
        XCTAssertEqual(try eval("5!"), "120")
        XCTAssertEqual(try eval("5 nCr 2"), "10")
        XCTAssertEqual(try eval("5 nPr 2"), "20")
        XCTAssertEqual(try eval("3 ˣ√ 27"), "3")
        XCTAssertEqual(try eval("2³"), "8")
    }

    func testFunctionsAndConstants() throws {
        XCTAssertEqual(try eval("√(2)"), "1.414213562")
        XCTAssertEqual(try eval("sin(π÷2)"), "1")
        XCTAssertEqual(try eval("sin(π÷2"), "1")
        XCTAssertEqual(try eval("2π"), "6.283185307")
        store.ans = .num(5)
        XCTAssertEqual(try eval("Ans+1"), "6")
        XCTAssertEqual(try eval("e^(1)"), "2.718281828")
        XCTAssertEqual(try eval("log(1000)"), "3")
        XCTAssertEqual(try eval("cos⁻¹(1)"), "0")
        XCTAssertEqual(try eval("abs(⁻7)"), "7")
        XCTAssertEqual(try eval("round(2.567,2)"), "2.57")
        XCTAssertEqual(try eval("gcd(12,18)"), "6")
        XCTAssertEqual(try eval("lcm(4,6)"), "12")
        XCTAssertEqual(try eval("int(⁻2.5)"), "⁻3")
        XCTAssertEqual(try eval("iPart(⁻2.5)"), "⁻2")
        XCTAssertEqual(try eval("logBASE(8,2)"), "3")
        XCTAssertEqual(try eval("³√(27)"), "3")
    }

    func testFractionsAndDegrees() throws {
        XCTAssertEqual(try eval(".5▶Frac"), "1/2")
        XCTAssertEqual(try eval("(1÷3+1÷6)▶Frac"), "1/2")
        XCTAssertEqual(try eval("⁻.75▶Frac"), "⁻3/4")
        store.options["angle"] = 1
        XCTAssertEqual(try eval("sin(30)"), ".5")
        XCTAssertEqual(try eval("cos⁻¹(0)"), "90")
        store.options["angle"] = 0
        XCTAssertEqual(try eval("sin(30°)"), ".5")
        XCTAssertEqual(try eval("1.5▶DMS"), "1°30'0\"")
    }

    func testTestsAndLogic() throws {
        XCTAssertEqual(try eval("3>2"), "1")
        XCTAssertEqual(try eval("3=2"), "0")
        XCTAssertEqual(try eval("2 and 0"), "0")
        XCTAssertEqual(try eval("2 or 0"), "1")
        XCTAssertEqual(try eval("1 xor 1"), "0")
        XCTAssertEqual(try eval("not(0)"), "1")
        XCTAssertEqual(try eval("1+1=2"), "1")
    }

    func testListsAndMatrices() throws {
        XCTAssertEqual(try eval("{1,2}+{3,4}"), "{4 6}")
        XCTAssertEqual(try eval("2×{1,2,3}"), "{2 4 6}")
        XCTAssertEqual(try eval("sum({1,2,3})"), "6")
        XCTAssertEqual(try eval("mean({1,2,3})"), "2")
        XCTAssertEqual(try eval("median({5,1,3})"), "3")
        XCTAssertEqual(try eval("seq(X²,X,1,4)"), "{1 4 9 16}")
        XCTAssertEqual(try eval("Σ(X,X,1,10)"), "55")
        XCTAssertEqual(try eval("dim({1,2,3})"), "3")
        XCTAssertEqual(try eval("cumSum({1,2,3})"), "{1 3 6}")
        XCTAssertEqual(try eval("det([[1,2][3,4]])"), "⁻2")
        XCTAssertEqual(try eval("[[1,2][3,4]]ᵀ"), "[[1 3]\n [2 4]]")
        XCTAssertEqual(try eval("[[1,2][3,4]]×[[1,0][0,1]]"), "[[1 2]\n [3 4]]")
        XCTAssertEqual(try eval("[[2,0][0,2]]⁻¹"), "[[.5 0]\n [0 .5]]")
        XCTAssertEqual(try eval("identity(2)"), "[[1 0]\n [0 1]]")
        XCTAssertEqual(try eval("rref([[1,2][3,4]])"), "[[1 0]\n [0 1]]")
        XCTAssertThrowsError(try eval("[[1,2]]+[[1][2]]")) { XCTAssertEqual($0 as? CalcError, .dimMismatch) }
        XCTAssertThrowsError(try eval("[[1,2][2,4]]⁻¹")) { XCTAssertEqual($0 as? CalcError, .singular) }
    }

    func testStoreAndRecall() throws {
        XCTAssertEqual(try eval("5→A"), "5")
        XCTAssertEqual(try eval("A²"), "25")
        XCTAssertEqual(try eval("{1,2,3}→L₁"), "{1 2 3}")
        XCTAssertEqual(try eval("sum(L₁)"), "6")
        XCTAssertEqual(try eval("[[1,2][3,4]]→[A]"), "[[1 2]\n [3 4]]")
        XCTAssertEqual(try eval("det([A])"), "⁻2")
        XCTAssertEqual(try eval("\"X²\"→Y₁"), "X²")
        store.reals["X"] = 3
        XCTAssertEqual(try eval("Y₁"), "9")
        XCTAssertEqual(try eval("Degree"), "Done")
        XCTAssertTrue(store.degrees)
        XCTAssertEqual(try eval("Radian"), "Done")
        XCTAssertEqual(try eval("ZStandard"), "Done")
        XCTAssertEqual(store.numbers["Xmin"], -10)
        XCTAssertEqual(try eval("Fix 2"), "Done")
        XCTAssertEqual(try eval("1÷3"), ".33")
        XCTAssertEqual(try eval("Float"), "Done")
        XCTAssertEqual(try eval("Sci"), "Done")
        XCTAssertEqual(try eval("1234"), "1.234ᴇ3")
        XCTAssertEqual(try eval("Normal"), "Done")
    }

    func testDistributions() throws {
        XCTAssertEqual(try eval("normalcdf(⁻1,1)"), ".6826894921")
        XCTAssertEqual(try eval("round(invNorm(.975),4)"), "1.96")
        XCTAssertEqual(try eval("binompdf(10,.5,5)"), ".24609375")
        XCTAssertEqual(try eval("round(poissonpdf(2,3),6)"), ".180447")
        XCTAssertEqual(try eval("round(tcdf(⁻2,2,10),4)"), ".9266")
    }

    func testErrors() {
        XCTAssertThrowsError(try eval("1÷0")) { XCTAssertEqual($0 as? CalcError, .divideByZero) }
        XCTAssertThrowsError(try eval("√(⁻1)")) { XCTAssertEqual($0 as? CalcError, .domain) }
        XCTAssertThrowsError(try eval("sin⁻¹(2)")) { XCTAssertEqual($0 as? CalcError, .domain) }
        XCTAssertThrowsError(try eval("2+")) { XCTAssertEqual($0 as? CalcError, .syntax) }
        XCTAssertThrowsError(try eval("2⁻3")) { XCTAssertEqual($0 as? CalcError, .syntax) }
        XCTAssertThrowsError(try eval("{1,2}+{1,2,3}")) { XCTAssertEqual($0 as? CalcError, .dimMismatch) }
        XCTAssertThrowsError(try eval("[B]")) { XCTAssertEqual($0 as? CalcError, .undefined) }
    }

    func testStatsAndTVM() throws {
        let one = try Stats.oneVar([2, 4, 4, 4, 5, 5, 7, 9])
        XCTAssertEqual(one.first { $0.0 == "x̄" }?.1, 5)
        XCTAssertEqual(one.first { $0.0 == "σx" }?.1, 2)
        let lr = try Stats.linReg([1, 2, 3, 4], [2, 4, 6, 8])
        XCTAssertEqual(lr.a, 2, accuracy: 1e-9)
        XCTAssertEqual(lr.b, 0, accuracy: 1e-9)
        XCTAssertEqual(lr.r, 1, accuracy: 1e-9)
        let q = try Stats.polyReg([0, 1, 2, 3], [1, 2, 5, 10], degree: 2)
        XCTAssertEqual(q[0], 1, accuracy: 1e-9)
        XCTAssertEqual(q[2], 1, accuracy: 1e-9)
        let pmt = try Stats.tvmSolve("PMT", ["N": 360, "I%": 6, "PV": 250000, "FV": 0, "P/Y": 12, "C/Y": 12], begin: false)
        XCTAssertEqual(pmt, -1498.88, accuracy: 0.01)
    }
}
