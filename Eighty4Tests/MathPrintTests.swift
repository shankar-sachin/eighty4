import XCTest
@testable import Eighty4

/// MATHPRINT templates (n/d, Un/d, piecewise), their layout, MODE ANSWERS, and complex matrices.
final class MathPrintTests: XCTestCase {
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

    private func frac(_ n: String, _ d: String) -> String { MathPrint.fraction(n, d) }

    // MARK: - Templates in the engine

    func testFractionTemplates() throws {
        XCTAssertEqual(try eval(frac("1", "2")), "1/2")
        XCTAssertEqual(try eval(frac("2", "4")), "1/2")                         // reduced
        XCTAssertEqual(try eval(frac("3", "⁻6")), "⁻1/2")
        XCTAssertEqual(try eval(frac("1", "2") + "+" + frac("1", "4")), ".75")  // arithmetic on fractions is numeric
        XCTAssertEqual(try eval("1÷4▶Frac"), "1/4")                               // ▶Frac converts the whole entry
        XCTAssertEqual(try eval("2+1÷4▶Frac"), "9/4")
        XCTAssertEqual(try eval(frac("1.5", "2")), ".75")                       // non-integers divide
        XCTAssertEqual(try eval(frac("1+1", "2×2")), "1/2")                     // slots hold expressions
        XCTAssertEqual(try eval(frac(frac("1", "2"), "3")), "1/6")              // nested
        XCTAssertEqual(try eval("2" + frac("1", "2")), "1")                     // implicit multiplication
        XCTAssertEqual(try eval(MathPrint.mixed("2", "1", "2")), "5/2")
        XCTAssertEqual(try eval(MathPrint.mixed("⁻2", "1", "2")), "⁻5/2")
        XCTAssertEqual(try eval(MathPrint.mixed("1", "1", "3") + "▶Dec"), "1.333333333")
        assertError(frac("", "2"), .syntax)
        assertError(frac("1", "0"), .divideByZero)
        XCTAssertEqual(MathPrint.classic(frac("1", "2")), "(1)/(2)")
        XCTAssertEqual(MathPrint.classic(MathPrint.piecewise(rows: 2)), "piecewise(,,,)")
        XCTAssertEqual(try eval("identity(2)"), "[[1 0]\n [0 1]]")
        XCTAssertEqual(try eval("[[2,0][0,2]]⁻¹"), "[[.5 0]\n [0 .5]]")
        XCTAssertEqual(try eval("[[1,1][0,1]]^3"), "[[1 3]\n [0 1]]")
    }

    func testPiecewise() throws {
        XCTAssertEqual(try eval("piecewise(1,2<1,2,2>1)"), "2")
        XCTAssertEqual(try eval("piecewise(X²,X<0,X,X≥0)"), "0")
        store.reals["X"] = -3
        XCTAssertEqual(try eval("piecewise(X²,X<0,X,X≥0)"), "9")
        XCTAssertEqual(try eval("piecewise(1,X>0,7)"), "7")                     // trailing else piece
        assertError("piecewise(1,X>0)", .domain)
        XCTAssertEqual(try eval("piecewise(1÷0,X>0,5,X<0)"), "5")                // pieces stay lazy
        assertError("piecewise(1÷0,X<0,5,X>0)", .divideByZero)
        XCTAssertEqual(try eval("piecewise(1,X<0,2)"), "1")
        // The template form tokenizes to the same call.
        let t = "\(MathPrint.stackOpen)X²\(MathPrint.colSep)X<0\(MathPrint.rowSep)X\(MathPrint.colSep)X≥0\(MathPrint.stackClose)"
        XCTAssertEqual(try eval(t), "9")
    }

    func testAnswersModeAndMathPrintFormatting() throws {
        let s = CalculatorState()
        func type(_ text: String) { s.entry = Array(text); s.cursor = s.entry.count; s.evaluate() }
        s.store.options["mathprint"] = 0
        type(frac("1", "2") + "+" + frac("1", "4"))
        XCTAssertEqual(s.history.last?.text, frac("3", "4"))                    // AUTO: template in → stacked fraction out
        XCTAssertEqual(s.history.last?.rows, 2)
        type("1÷4")
        XCTAssertEqual(s.history.last?.text, ".25")                             // AUTO: no template → decimal
        type("1÷4▶Frac")
        XCTAssertEqual(s.history.last?.text, frac("1", "4"))
        s.store.options["answers"] = 2                                          // FRAC
        type("1÷4")
        XCTAssertEqual(s.history.last?.text, frac("1", "4"))
        s.store.options["answers"] = 1                                          // DEC
        type(frac("1", "4"))
        XCTAssertEqual(s.history.last?.text, ".25")
        s.store.options["answers"] = 0
        s.store.options["mathprint"] = 1                                        // CLASSIC: flat fractions
        type(frac("1", "2") + "+" + frac("1", "4"))
        XCTAssertEqual(s.history.last?.text, "3/4")
        s.store.options["fraction"] = 1                                         // Un/d
        s.store.options["mathprint"] = 0
        type("7÷2▶Frac")
        XCTAssertEqual(s.history.last?.text, MathPrint.mixed("3", "1", "2"))
        XCTAssertTrue(s.store.statusText.hasSuffix("MP"))
        s.store.options["mathprint"] = 1
        XCTAssertFalse(s.store.statusText.hasSuffix("MP"))
    }

    // MARK: - Layout and entry editing

    func testLayoutOfFractions() {
        let l = MathLayout.layout("1+" + frac("2", "34") + "=", width: 26)
        XCTAssertEqual(l.rows.count, 1)
        XCTAssertEqual(l.rows[0].height, 2)
        XCTAssertEqual(l.rows[0].width, 5)                                      // "1+" + 2-wide fraction + "="
        let glyph = { (c: Character) in l.rows[0].glyphs.first { $0.ch == c } }
        XCTAssertEqual(glyph("1")?.y, 0.5)                                      // text sits on the bar
        XCTAssertEqual(glyph("2")?.y, 0)
        XCTAssertEqual(glyph("2")?.x, 2.5)                                      // numerator centred over "34"
        XCTAssertEqual(glyph("3")?.y, 1)
        XCTAssertEqual(glyph("=")?.x, 4)
        XCTAssertEqual(l.rows[0].bars, [MathLayout.Bar(x0: 2, x1: 4, y: 1)])
        // Cursor slots: before the fraction, in the numerator, at the numerator end, in the denominator, after.
        XCTAssertEqual(l.cursor(at: 2).x, 2); XCTAssertEqual(l.cursor(at: 2).y, 0.5)
        XCTAssertEqual(l.cursor(at: 3).x, 2.5); XCTAssertEqual(l.cursor(at: 3).y, 0)
        XCTAssertEqual(l.cursor(at: 4).x, 3.5)
        XCTAssertEqual(l.cursor(at: 5).x, 2); XCTAssertEqual(l.cursor(at: 5).y, 1)
        XCTAssertEqual(l.cursor(at: 8).x, 4); XCTAssertEqual(l.cursor(at: 8).y, 0.5)
        XCTAssertEqual(l.cursor(at: 9).x, 5)
        // Empty slots draw placeholders and still take a cursor.
        let e = MathLayout.layout(MathPrint.fractionTemplate, width: 26)
        XCTAssertEqual(e.rows[0].glyphs.filter(\.placeholder).count, 2)
        XCTAssertEqual(e.cursor(at: 1).y, 0)
        XCTAssertEqual(e.cursor(at: 2).y, 1)
        // Nested fractions grow the row; plain text wraps at the width.
        XCTAssertEqual(MathLayout.layout(frac(frac("1", "2"), "3"), width: 26).rows[0].height, 3)
        XCTAssertEqual(MathLayout.layout(String(repeating: "1", count: 30), width: 26).rows.count, 2)
        // Templates never split across rows.
        let w = MathLayout.layout(String(repeating: "1", count: 26) + frac("1", "2"), width: 26)
        XCTAssertEqual(w.rows.count, 2)
        XCTAssertEqual(w.rows[1].height, 2)
        let p = MathLayout.layout(MathPrint.piecewise(rows: 2), width: 26)
        XCTAssertEqual(p.rows[0].height, 2)
        XCTAssertEqual(p.rows[0].braces.count, 1)
    }

    func testTemplateEditingOnHome() {
        let s = CalculatorState()
        s.store.options["mathprint"] = 0
        func keys(_ k: [KeyID]) { k.forEach { s.press($0) } }
        keys([.math, .left, .one])                                              // FRAC 1:n/d
        XCTAssertEqual(String(s.entry), MathPrint.fractionTemplate)
        XCTAssertEqual(s.cursor, 1)                                             // in the numerator
        keys([.one, .right, .two, .right, .plus, .three])
        XCTAssertEqual(String(s.entry), frac("1", "2") + "+3")
        XCTAssertEqual(s.cursorPosition.y, 0.5)
        keys([.enter])
        XCTAssertEqual(s.history.last?.text, frac("7", "2"))
        XCTAssertEqual(s.history.last?.rows, 2)
        XCTAssertEqual(s.placedLines.count, 3)
        XCTAssertEqual(s.placedLines[1].row, 2)                                 // answer starts under the 2-row entry
        XCTAssertEqual(s.placedLines[2].row, 4)
        // ▲ selects the stacked answer, ENTER pastes it as a template.
        keys([.up, .enter])
        XCTAssertEqual(String(s.entry), frac("7", "2"))
        // DEL on any delimiter removes the whole template.
        keys([.left, .del])
        XCTAssertEqual(s.entry, [])
        keys([.math, .left, .two])                                              // Un/d
        XCTAssertEqual(String(s.entry), MathPrint.mixedTemplate)
        keys([.two, .right, .one, .right, .three, .enter])
        XCTAssertEqual(s.history.last?.text, frac("7", "3"))
        // In CLASSIC mode the same menu inserts the flat tokens.
        s.store.options["mathprint"] = 1
        keys([.clear, .math, .left, .one])
        XCTAssertEqual(String(s.entry), "/")
        // The Y= editor never gets stacked templates.
        s.store.options["mathprint"] = 0
        keys([.clear, .yEquals, .one, .math, .left, .one, .two])
        XCTAssertEqual(String(s.entry), "1/2")
        keys([.math, .up, .up, .enter, .two])
        XCTAssertEqual(String(s.entry), "1/2piecewise(")
    }

    func testPiecewiseMenuAndGraph() {
        let s = CalculatorState()
        s.store.options["mathprint"] = 0
        func keys(_ k: [KeyID]) { k.forEach { s.press($0) } }
        keys([.math, .up, .up, .enter])                                         // MATH B:piecewise( → PIECEWISE submenu
        XCTAssertEqual(s.screen, .menu(.piecewise))
        keys([.two])
        XCTAssertEqual(String(s.entry), MathPrint.piecewise(rows: 2))
        XCTAssertEqual(s.cursor, 1)
        // Fill both rows in overwrite mode: the template's own separators are never overwritten.
        keys([.xtn, .square, .right, .xtn, .second, .math, .five, .zero, .right, .xtn, .right, .xtn, .second, .math, .four, .zero])
        XCTAssertEqual(MathPrint.classic(String(s.entry)), "piecewise(X²,X<0,X,X≥0)")
        keys([.enter])
        XCTAssertEqual(s.history.last?.text, "0")
        s.store.yFuncs[1] = "piecewise(X,X<0,X²,X≥0)"
        XCTAssertEqual(Graphing.y(1, at: -2, store: s.store), -2)
        XCTAssertEqual(Graphing.y(1, at: 3, store: s.store), 9)
    }

    // MARK: - Complex matrices

    func testComplexMatrices() throws {
        XCTAssertEqual(try eval("[[1,i][2,3]]"), "[[1 i]\n [2 3]]")
        XCTAssertEqual(try eval("[[1,i][2,3]]+[[0,⁻i][0,0]]"), "[[1 0]\n [2 3]]")   // collapses to real
        XCTAssertEqual(try eval("[[1,2][3,4]]×i"), "[[i 2i]\n [3i 4i]]")
        XCTAssertEqual(try eval("i[[1,2][3,4]]"), "[[i 2i]\n [3i 4i]]")
        XCTAssertEqual(try eval("[[i,0][0,i]]²"), "[[⁻1 0]\n [0 ⁻1]]")
        XCTAssertEqual(try eval("[[i,0][0,i]][[1,1][1,1]]"), "[[i i]\n [i i]]")
        XCTAssertEqual(try eval("det([[1,i][i,1]])"), "2")
        XCTAssertEqual(try eval("det([[i,0][0,i]])"), "⁻1")
        XCTAssertEqual(try eval("[[i,0][0,2]]⁻¹"), "[[⁻i 0]\n [0 .5]]")
        XCTAssertEqual(try eval("[[i,0][0,2]]^⁻1"), "[[⁻i 0]\n [0 .5]]")
        XCTAssertEqual(try eval("[[1,i]]ᵀ"), "[[1]\n [i]]")
        XCTAssertEqual(try eval("conj([[1,i]])"), "[[1 ⁻i]]")
        XCTAssertEqual(try eval("real([[1+2i,3]])"), "[[1 3]]")
        XCTAssertEqual(try eval("imag([[1+2i,3]])"), "[[2 0]]")
        XCTAssertEqual(try eval("abs([[3+4i,⁻2]])"), "[[5 2]]")
        XCTAssertEqual(try eval("dim([[1,i][2,3]])"), "{2 2}")
        XCTAssertEqual(try eval("augment([[i]],[[2]])"), "[[i 2]]")
        XCTAssertEqual(try eval("cumSum([[i][1]])"), "[[i]\n [1+i]]")
        XCTAssertEqual(try eval("rref([[i,i][1,2]])"), "[[1 0]\n [0 1]]")
        XCTAssertEqual(try eval("rowSwap([[i][2]],1,2)"), "[[2]\n [i]]")
        XCTAssertEqual(try eval("*row(i,[[1,2]],1)"), "[[i 2i]]")
        XCTAssertEqual(try eval("*row+(i,[[1][1]],1,2)"), "[[1]\n [1+i]]")
        XCTAssertEqual(try eval("⁻[[i]]"), "[[⁻i]]")
        assertError("[[1,i]]+[[1]]", .dimMismatch)
        assertError("[[1,i]]÷[[1,i]]", .dataType)
        assertError("[[1,i]]^.5", .dataType)
        assertError("det([[1,i]])", .invalidDim)
        assertError("[[0,0][0,0]]⁻¹", .singular)
        store.options["complex"] = 2
        XCTAssertEqual(try eval("[[2i]]"), "[[2e^(1.570796327i)]]")
    }

    func testComplexMatrixStorageAndEditor() throws {
        XCTAssertEqual(try eval("[[1,i][2,3]]→[A]"), "[[1 i]\n [2 3]]")
        XCTAssertEqual(store.complexMatrices["A"], [[[1, 0], [0, 1]], [[2, 0], [3, 0]]])
        XCTAssertEqual(store.matrices["A"], [[1, 0], [2, 3]])                   // real part keeps dims for menus
        XCTAssertEqual(try eval("[A]×2"), "[[2 2i]\n [4 6]]")
        XCTAssertEqual(try eval("[[5]]→[A]"), "[[5]]")
        XCTAssertNil(store.complexMatrices["A"])
        XCTAssertEqual(try eval("[[i][2]]→[C]"), "[[i]\n [2]]")
        XCTAssertEqual(try eval("Matr▶list([C],L₁)"), "Done")
        XCTAssertEqual(store.complexLists["L1"], [[0, 1], [2, 0]])
        XCTAssertEqual(try eval("List▶matr({1,i},[B])"), "Done")
        XCTAssertEqual(try eval("[B]"), "[[1]\n [i]]")
        XCTAssertEqual(try eval("Fill(i,[B])"), "Done")
        XCTAssertEqual(try eval("[B]"), "[[i]\n [i]]")
        XCTAssertTrue(MemoryModel.items(store).contains { $0.name == "[B]" && $0.category == "Complex" })
        store.deleteVariable("[B]")
        XCTAssertNil(store.complexMatrices["B"])
        XCTAssertNil(store.matrices["B"])

        // Matrix editor: typing "i" into a cell makes [C] complex, overwriting it with a real collapses it back.
        let s = CalculatorState()
        func keys(_ k: [KeyID]) { k.forEach { s.press($0) } }
        keys([.second, .inverse, .right, .right, .three, .enter, .enter, .second, .dot, .enter])
        XCTAssertEqual(s.store.complexMatrices["C"], [[[0, 1]]])
        XCTAssertEqual(s.store.matrices["C"], [[0]])
        keys([.four, .enter])
        XCTAssertNil(s.store.complexMatrices["C"])
        XCTAssertEqual(s.store.matrices["C"], [[4]])
        keys([.second, .mode, .second, .inverse, .three, .enter])
        XCTAssertEqual(s.history.last?.text, "[[4]]")
    }
}
