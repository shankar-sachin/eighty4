import Foundation

enum Command: Equatable {
    case zoom(ZoomKind)
    case clearEntries, about
    case oneVar, twoVar, linReg, linRegAlt, quadReg, cubicReg, quartReg, expReg, lnReg, pwrReg, medMed, logistic, sinReg
    /// TI-84 Evo regressions: y=ax, y=a+b/x, y=ae^(bx).
    case propReg, recipReg, eBaseReg
    case listEditor, matrixEdit(String)
    case calc(CalcOp), trace
    case linkSend, linkReceive
    case clrDraw, insertRegEQ
    case solver, pen, zbox
    case statTest(StatTest)
    case runProgram(String), editProgram(String), newProgram
    case varList(VarListMode), confirm(ConfirmKind)
    case createGroup, ungroup(String)
}

enum MenuAction: Equatable {
    case insert(String)
    case editor(EditorID)
    case app(AppID)
    case command(Command)
    case submenu(MenuID)
}

struct MenuItem {
    let label: String
    let action: MenuAction
}

struct MenuTab {
    let title: String
    let items: [MenuItem]
}

struct MenuDef {
    let tabs: [MenuTab]
}

enum Menus {
    static func indexLabel(_ i: Int) -> String {
        if i < 9 { return String(i + 1) }
        if i == 9 { return "0" }
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let k = i - 10
        return k < letters.count ? String(letters[k]) : "·"
    }

    private static func ins(_ s: String) -> MenuItem { MenuItem(label: s, action: .insert(s)) }
    private static func ins(_ label: String, _ s: String) -> MenuItem { MenuItem(label: label, action: .insert(s)) }
    private static func cmd(_ label: String, _ c: Command) -> MenuItem { MenuItem(label: label, action: .command(c)) }
    private static func sub(_ label: String, _ id: MenuID) -> MenuItem { MenuItem(label: label, action: .submenu(id)) }
    private static func app(_ label: String, _ id: AppID) -> MenuItem { MenuItem(label: label, action: .app(id)) }

    static let builtInPrograms: [(String, AppID)] = [("GEODASH", .geoDash), ("TETRIS", .tetris)]

    static func def(_ id: MenuID, store: VariableStore) -> MenuDef {
        let subs = Tokenizer.subscripts
        switch id {
        case .math:
            // MATHPRINT mode inserts the stacked templates; CLASSIC inserts the flat tokens.
            let mp = store.mathPrint
            let piecewise = mp ? sub("piecewise(", .piecewise) : ins("piecewise(")
            return MenuDef(tabs: [
                MenuTab(title: "MATH", items: [ins("▶Frac"), ins("▶Dec"), ins("³"), ins("³√("), ins("ˣ√"), ins("fMin("), ins("fMax("), ins("nDeriv("), ins("fnInt("), ins("Σ("), ins("logBASE("), piecewise, cmd("Solver…", .solver)]),
                MenuTab(title: "NUM", items: [ins("abs("), ins("round("), ins("iPart("), ins("fPart("), ins("int("), ins("min("), ins("max("), ins("lcm("), ins("gcd("), ins("remainder("), ins("toString("), ins("eval(")]),
                MenuTab(title: "CMPLX", items: [ins("conj("), ins("real("), ins("imag("), ins("angle("), ins("abs("), ins("▶Rect"), ins("▶Polar")]),
                MenuTab(title: "PROB", items: [ins("rand"), ins("nPr", " nPr "), ins("nCr", " nCr "), ins("!"), ins("randInt("), ins("randNorm("), ins("randBin("), ins("randIntNoRep(")]),
                MenuTab(title: "FRAC", items: [ins("n/d", mp ? MathPrint.fractionTemplate : "/"), ins("Un/d", mp ? MathPrint.mixedTemplate : "_"), ins("▶n/d◀▶Un/d"), ins("▶F◀▶D")]),
            ])
        case .piecewise:
            return MenuDef(tabs: [MenuTab(title: "PIECEWISE", items: (1...5).map { ins("\($0) piece" + ($0 == 1 ? "" : "s"), MathPrint.piecewise(rows: $0)) })])
        case .test:
            return MenuDef(tabs: [
                MenuTab(title: "TEST", items: [ins("="), ins("≠"), ins(">"), ins("≥"), ins("<"), ins("≤")]),
                MenuTab(title: "LOGIC", items: [ins("and", " and "), ins("or", " or "), ins("xor", " xor "), ins("not(")]),
            ])
        case .angle:
            return MenuDef(tabs: [MenuTab(title: "ANGLE", items: [ins("°"), ins("'"), ins("ʳ"), ins("▶DMS"), ins("R▶Pr("), ins("R▶Pθ("), ins("P▶Rx("), ins("P▶Ry(")])])
        case .distr where store.evo:
            // The Evo groups the distributions by family, with the DRAW command in its family's tab.
            return MenuDef(tabs: [
                MenuTab(title: "NORMAL", items: [ins("normalpdf("), ins("normalcdf("), ins("invNorm("), ins("ShadeNorm(")]),
                MenuTab(title: "t", items: [ins("tpdf("), ins("tcdf("), ins("invT("), ins("Shade_t(")]),
                MenuTab(title: "χ²", items: [ins("χ²pdf("), ins("χ²cdf("), ins("Shadeχ²(")]),
                MenuTab(title: "F", items: [ins("Fpdf("), ins("Fcdf("), ins("ShadeF(")]),
                MenuTab(title: "DISCRETE", items: [ins("binompdf("), ins("binomcdf("), ins("invBinom("), ins("poissonpdf("), ins("poissoncdf("), ins("geometpdf("), ins("geometcdf(")]),
            ])
        case .distr:
            return MenuDef(tabs: [
                MenuTab(title: "DISTR", items: [ins("normalpdf("), ins("normalcdf("), ins("invNorm("), ins("invT("), ins("tpdf("), ins("tcdf("), ins("χ²pdf("), ins("χ²cdf("), ins("Fpdf("), ins("Fcdf("), ins("binompdf("), ins("binomcdf("), ins("invBinom("), ins("poissonpdf("), ins("poissoncdf("), ins("geometpdf("), ins("geometcdf(")]),
                MenuTab(title: "DRAW", items: [ins("ShadeNorm("), ins("Shade_t("), ins("Shadeχ²("), ins("ShadeF(")]),
            ])
        case .list:
            return MenuDef(tabs: [
                MenuTab(title: "NAMES", items: (1...6).map { ins("L\(subs[$0])") }),
                MenuTab(title: "OPS", items: [ins("SortA("), ins("SortD("), ins("dim("), ins("Fill("), ins("seq("), ins("cumSum("), ins("ΔList("), ins("augment(")]),
                MenuTab(title: "MATH", items: [ins("min("), ins("max("), ins("mean("), ins("median("), ins("sum("), ins("prod("), ins("stdDev("), ins("variance(")]),
            ])
        case .vars:
            return MenuDef(tabs: [
                MenuTab(title: "VARS", items: [sub("Window…", .varsWindow), sub("Zoom…", .varsZoom), sub("GDB…", .varsGDB), sub("Picture…", .varsPic), sub("Statistics…", .varsStats), sub("Table…", .varsTable), sub("String…", .varsStr)]),
                MenuTab(title: "Y-VARS", items: [sub("Function…", .yvars), sub("Parametric…", .yvarsParam), sub("Polar…", .yvarsPolar), sub("On/Off…", .fnOnOff), sub("Sequence…", .yvarsSeq)]),
            ])
        case .varsWindow:
            return MenuDef(tabs: [
                MenuTab(title: "X/Y", items: [ins("Xmin"), ins("Xmax"), ins("Xscl"), ins("Ymin"), ins("Ymax"), ins("Yscl"), ins("Xres")]),
                MenuTab(title: "T/θ", items: [ins("Tmin"), ins("Tmax"), ins("Tstep"), ins("θmin"), ins("θmax"), ins("θstep")]),
                MenuTab(title: "U/V/W", items: [ins("nMin"), ins("nMax"), ins("PlotStart"), ins("PlotStep")]),
            ])
        case .varsZoom:
            return MenuDef(tabs: [MenuTab(title: "ZX/ZY", items: [ins("XFact"), ins("YFact")])])
        case .varsGDB:
            return MenuDef(tabs: [MenuTab(title: "GRAPH DATABASE", items: (1...10).map { ins("GDB\($0 % 10)") })])
        case .varsPic:
            return MenuDef(tabs: [MenuTab(title: "PICTURE", items: (1...10).map { ins("Pic\($0 % 10)") })])
        case .varsStr:
            return MenuDef(tabs: [MenuTab(title: "STRING", items: (1...10).map { ins("Str\($0 % 10)") })])
        case .varsStats:
            return MenuDef(tabs: [
                MenuTab(title: "XY", items: [ins("n"), ins("x̄"), ins("Sx"), ins("σx"), ins("ȳ"), ins("Sy"), ins("σy"), ins("minX"), ins("maxX"), ins("minY"), ins("maxY")]),
                MenuTab(title: "Σ", items: [ins("Σx"), ins("Σx²"), ins("Σy"), ins("Σy²"), ins("Σxy")]),
                MenuTab(title: "EQ", items: [cmd("RegEQ", .insertRegEQ), ins("a"), ins("b"), ins("c"), ins("d"), ins("r"), ins("r²")]),
                MenuTab(title: "TEST", items: [ins("p"), ins("z"), ins("t"), ins("χ²", "χ²"), ins("F"), ins("df"), ins("p̂"), ins("p̂1"), ins("p̂2"), ins("x̄1"), ins("x̄2"), ins("Sx1"), ins("Sx2"), ins("Sxp"), ins("n1"), ins("n2"), ins("lower"), ins("upper"), ins("s")]),
                MenuTab(title: "PTS", items: [ins("Q1"), ins("Med"), ins("Q3")]),
            ])
        case .varsTable:
            return MenuDef(tabs: [MenuTab(title: "TABLE", items: [ins("TblStart"), ins("ΔTbl")])])
        case .yvars:
            return MenuDef(tabs: [MenuTab(title: "FUNCTION", items: (0...9).map { i in let n = i == 9 ? 0 : i + 1; return ins("Y\(subs[n])") })])
        case .yvarsParam:
            return MenuDef(tabs: [MenuTab(title: "PARAMETRIC", items: (1...6).flatMap { [ins("X\(subs[$0])T"), ins("Y\(subs[$0])T")] })])
        case .yvarsPolar:
            return MenuDef(tabs: [MenuTab(title: "POLAR", items: (1...6).map { ins("r\(subs[$0])") })])
        case .yvarsSeq:
            return MenuDef(tabs: [MenuTab(title: "SEQUENCE", items: [ins("u"), ins("v"), ins("w")])])
        case .fnOnOff:
            return MenuDef(tabs: [MenuTab(title: "ON/OFF", items: [ins("FnOn"), ins("FnOff")])])
        case .matrix:
            let letters = Array("ABCDEFGHIJ").map(String.init)
            func nameLabel(_ l: String) -> String {
                if let m = store.matrices[l] { let (r, c) = Matrix.dims(m); return "[\(l)]  \(r)×\(c)" }
                return "[\(l)]"
            }
            return MenuDef(tabs: [
                MenuTab(title: "NAMES", items: letters.map { ins(nameLabel($0), "[\($0)]") }),
                MenuTab(title: "MATH", items: [ins("det("), ins("ᵀ"), ins("dim("), ins("Fill("), ins("identity("), ins("randM("), ins("augment("), ins("Matr▶list("), ins("List▶matr("), ins("cumSum("), ins("ref("), ins("rref("), ins("rowSwap("), ins("row+("), ins("*row("), ins("*row+(")]),
                MenuTab(title: "EDIT", items: letters.map { cmd(nameLabel($0), .matrixEdit($0)) }),
            ])
        case .stat:
            let edit = MenuTab(title: "EDIT", items: [cmd("Edit…", .listEditor), ins("SortA("), ins("SortD("), ins("ClrList", "ClrList "), ins("SetUpEditor")])
            var calc = [cmd("1-Var Stats", .oneVar), cmd("2-Var Stats", .twoVar), cmd("Med-Med", .medMed), cmd("LinReg(ax+b)", .linReg), cmd("QuadReg", .quadReg), cmd("CubicReg", .cubicReg), cmd("QuartReg", .quartReg), cmd("LinReg(a+bx)", .linRegAlt), cmd("LnReg", .lnReg), cmd("ExpReg", .expReg), cmd("PwrReg", .pwrReg), cmd("Logistic", .logistic), cmd("SinReg", .sinReg)]
            if store.evo {
                // The Evo adds three regressions and splits TESTS into INTERVALS and TESTS.
                calc += [cmd("PropReg", .propReg), cmd("RecipReg", .recipReg), cmd("eBASEReg", .eBaseReg)]
                let intervals = StatTest.allCases.filter(\.isInterval).map { cmd($0.title + "…", .statTest($0)) }
                let tests = StatTest.allCases.filter { !$0.isInterval }.map { cmd($0.title + "…", .statTest($0)) } + [ins("ANOVA(")]
                return MenuDef(tabs: [edit, MenuTab(title: "CALC", items: calc), MenuTab(title: "INTERVALS", items: intervals), MenuTab(title: "TESTS", items: tests)])
            }
            return MenuDef(tabs: [
                edit,
                MenuTab(title: "CALC", items: calc),
                MenuTab(title: "TESTS", items: StatTest.allCases.map { cmd($0.title + "…", .statTest($0)) } + [ins("ANOVA(")]),
            ])
        case .shortcut(let n):
            // alpha + f1…f4 shortcut menus (FRAC, FUNC, MTRX, YVAR).
            let mp = store.mathPrint
            switch n {
            case 1: return MenuDef(tabs: [MenuTab(title: "FRAC", items: [ins("n/d", mp ? MathPrint.fractionTemplate : "/"), ins("Un/d", mp ? MathPrint.mixedTemplate : "_"), ins("▶n/d◀▶Un/d"), ins("▶F◀▶D")])])
            case 2: return MenuDef(tabs: [MenuTab(title: "FUNC", items: [ins("abs("), ins("√("), ins("ˣ√"), ins("logBASE("), ins("Σ("), ins("nDeriv("), ins("fnInt("), ins("e^("), ins("10^(")])])
            case 3: return MenuDef(tabs: [MenuTab(title: "MTRX", items: [ins("["), ins("]"), ins("det("), ins("ᵀ"), ins("dim("), ins("identity("), ins("augment("), ins("ref("), ins("rref(")])])
            default: return MenuDef(tabs: [MenuTab(title: "YVAR", items: (0...9).map { i in let k = i == 9 ? 0 : i + 1; return ins("Y\(subs[k])") })])
            }
        case .draw:
            return MenuDef(tabs: [
                MenuTab(title: "DRAW", items: [cmd("ClrDraw", .clrDraw), ins("Line("), ins("Horizontal", "Horizontal "), ins("Vertical", "Vertical "), ins("Tangent("), ins("DrawF", "DrawF "), ins("Shade("), ins("DrawInv", "DrawInv "), ins("Circle("), ins("Text("), cmd("Pen", .pen)]),
                MenuTab(title: "POINTS", items: [ins("Pt-On("), ins("Pt-Off("), ins("Pt-Change("), ins("Pxl-On("), ins("Pxl-Off("), ins("Pxl-Change("), ins("pxl-Test(")]),
                MenuTab(title: "STO", items: [ins("StorePic", "StorePic "), ins("RecallPic", "RecallPic "), ins("StoreGDB", "StoreGDB "), ins("RecallGDB", "RecallGDB ")]),
                MenuTab(title: "BACKGROUND", items: [ins("BackgroundOn", "BackgroundOn "), ins("BackgroundOff")]),
            ])
        case .prgm:
            let names = store.programs.keys.sorted()
            return MenuDef(tabs: [
                MenuTab(title: "EXEC", items: builtInPrograms.map { app($0.0, $0.1) } + names.map { cmd($0, .runProgram($0)) }),
                MenuTab(title: "EDIT", items: names.map { cmd(store.lockedPrograms.contains($0) ? $0 + " [LOCKED]" : $0, .editProgram($0)) }),
                MenuTab(title: "NEW", items: [cmd("Create New", .newProgram)]),
            ])
        case .prgmCtl:
            let names = store.programs.keys.sorted()
            return MenuDef(tabs: [
                MenuTab(title: "CTL", items: [ins("If", "If "), ins("Then"), ins("Else"), ins("For("), ins("While", "While "), ins("Repeat", "Repeat "), ins("End"), ins("Pause", "Pause "), ins("Lbl", "Lbl "), ins("Goto", "Goto "), ins("IS>("), ins("DS<("), ins("Menu("), ins("prgm"), ins("Return"), ins("Stop"), ins("DelVar", "DelVar "), ins("Wait", "Wait ")]),
                MenuTab(title: "I/O", items: [ins("Input", "Input "), ins("Prompt", "Prompt "), ins("Disp", "Disp "), ins("DispGraph"), ins("DispTable"), ins("Output("), ins("getKey"), ins("ClrHome"), ins("ClrTable")]),
                MenuTab(title: "EXEC", items: names.map { ins("prgm" + $0) }),
            ])
        case .apps:
            return MenuDef(tabs: [MenuTab(title: "APPLICATIONS", items: [
                app("GeoDash", .geoDash), app("Tetris", .tetris),
                MenuItem(label: "Finance…", action: .editor(.tvm)),
                app("CabriJr", .cabriJr), app("CelSheet", .celSheet), app("Conics", .conics), app("Inequalz", .inequalz),
                app("PlySmlt2", .plySmlt2), app("Prob Sim", .probSim), app("SciTools", .sciTools), app("Transfrm", .transfrm), app("Vernier", .vernier),
            ])])
        case .zoom:
            return MenuDef(tabs: [
                MenuTab(title: "ZOOM", items: [cmd("ZBox", .zbox), cmd("Zoom In", .zoom(.zoomIn)), cmd("Zoom Out", .zoom(.zoomOut)), cmd("ZDecimal", .zoom(.decimal)), cmd("ZSquare", .zoom(.square)), cmd("ZStandard", .zoom(.standard)), cmd("ZTrig", .zoom(.trig)), cmd("ZInteger", .zoom(.integer)), cmd("ZoomStat", .zoom(.stat)), cmd("ZoomFit", .zoom(.fit)), cmd("ZQuadrant1", .zoom(.quadrant1)), cmd("ZFrac1/2", .zoom(.frac(2))), cmd("ZFrac1/3", .zoom(.frac(3))), cmd("ZFrac1/4", .zoom(.frac(4)))]),
                MenuTab(title: "MEMORY", items: [cmd("ZPrevious", .zoom(.previous)), cmd("ZoomSto", .zoom(.sto)), cmd("ZoomRcl", .zoom(.rcl)), MenuItem(label: "SetFactors…", action: .editor(.zoomFactors))]),
            ])
        case .calc:
            let all = [cmd("value", .calc(.value)), cmd("zero", .calc(.zero)), cmd("minimum", .calc(.minimum)), cmd("maximum", .calc(.maximum)), cmd("intersect", .calc(.intersect)), cmd("dy/dx", .calc(.derivative)), cmd("∫f(x)dx", .calc(.integral))]
            let items = store.graphType == .function ? all : [all[0], all[5]]
            return MenuDef(tabs: [MenuTab(title: "CALCULATE", items: items)])
        case .mem:
            return MenuDef(tabs: [MenuTab(title: "MEMORY", items: [cmd("About", .about), sub("Mem Management/Delete…", .memMgmt), cmd("Clear Entries", .clearEntries), ins("ClrAllLists"), cmd("Archive…", .varList(.archive)), cmd("UnArchive…", .varList(.unarchive)), sub("Reset…", .reset), sub("Group…", .group), cmd("Garbage Collect…", .confirm(.garbageCollect))])])
        case .memMgmt:
            let cats = ["All", "Real", "Complex", "List", "Matrix", "Y-Vars", "Prgm", "Pic", "GDB", "String", "Apps", "AppVars", "Group"]
            return MenuDef(tabs: [MenuTab(title: "RAM FREE \(MemoryModel.ramFree(store))", items: cats.map { cmd($0 + "…", .varList(.manage($0))) })])
        case .group:
            let names = store.groups.keys.sorted()
            return MenuDef(tabs: [
                MenuTab(title: "GROUP", items: [cmd("Create New", .createGroup)]),
                MenuTab(title: "UNGROUP", items: names.map { cmd($0, .ungroup($0)) }),
            ])
        case .reset:
            return MenuDef(tabs: [
                MenuTab(title: "RAM", items: [cmd("All RAM…", .confirm(.resetRAM)), cmd("Defaults…", .confirm(.resetDefaults))]),
                MenuTab(title: "ARCHIVE", items: [cmd("Vars…", .confirm(.resetArchiveVars)), cmd("Apps…", .confirm(.resetArchiveApps)), cmd("Both…", .confirm(.resetArchiveBoth))]),
                MenuTab(title: "ALL", items: [cmd("All Memory…", .confirm(.resetRAM))]),
            ])
        case .link:
            return MenuDef(tabs: [
                MenuTab(title: "SEND", items: ["All+…", "All-…", "Prgm…", "List…", "Lists to TI82…", "GDB…", "Pic…", "Matrix…", "Real…", "Complex…", "Y-Vars…", "String…", "Apps…", "AppVars…", "Group…", "SendId", "SendOS"].map { cmd($0, .linkSend) }),
                MenuTab(title: "RECEIVE", items: [cmd("Receive", .linkReceive)]),
            ])
        case .statPlot:
            func plotLabel(_ i: Int) -> String {
                let on = store.plotOn(i) ? "On" : "Off"
                let x = store.options["plot\(i)X", default: 0] + 1, y = store.options["plot\(i)Y", default: 1] + 1
                return "Plot\(i)…\(on) L\(subs[x]) L\(subs[y])"
            }
            return MenuDef(tabs: [MenuTab(title: "STAT PLOTS", items: [
                MenuItem(label: plotLabel(1), action: .editor(.plot1)),
                MenuItem(label: plotLabel(2), action: .editor(.plot2)),
                MenuItem(label: plotLabel(3), action: .editor(.plot3)),
                ins("PlotsOff"), ins("PlotsOn"),
            ])])
        case .catalog:
            var names = Functions.allNames.map { $0 + "(" }
            names += Tokenizer.commands
            names += Tokenizer.programCommands
            names += Tokenizer.postfixes.filter { $0 != "⁻¹" }
            names += ["and", "or", "xor", "nCr", "nPr", "rand", "Ans", "π", "e", "!", "°", "ʳ", "ᵀ", "²", "³", "ˣ√", "√(", "=", "≠", "≥", "≤", "→", "getKey", "prgm"]
            names = Array(Set(names)).sorted { $0.lowercased() < $1.lowercased() }
            return MenuDef(tabs: [MenuTab(title: "CATALOG", items: names.map { name in
                if name == "and" || name == "or" || name == "xor" || name == "nCr" || name == "nPr" { return ins(name, " \(name) ") }
                if Tokenizer.programCommands.contains(name), !name.hasSuffix("(") { return ins(name, name + " ") }
                return ins(name)
            })])
        }
    }
}

/// Fake-but-consistent byte accounting for the MEM screens.
enum MemoryModel {
    static let ramTotal = 154_164
    static let arcTotal = 3_020_000

    struct Item {
        let name: String
        let category: String
        let bytes: Int
    }

    static func items(_ store: VariableStore) -> [Item] {
        var out: [Item] = []
        for (k, v) in store.reals.sorted(by: { $0.key < $1.key }) { _ = v; out.append(Item(name: k, category: "Real", bytes: 15)) }
        for k in store.complexes.keys.sorted() { out.append(Item(name: k, category: "Complex", bytes: 24)) }
        for k in ["L1", "L2", "L3", "L4", "L5", "L6"] where !(store.lists[k] ?? []).isEmpty || store.complexLists[k] != nil {
            out.append(Item(name: k, category: "List", bytes: 12 + 9 * (store.lists[k]?.count ?? 0) + 18 * (store.complexLists[k]?.count ?? 0)))
        }
        for (k, m) in store.matrices.sorted(by: { $0.key < $1.key }) {
            let (r, c) = Matrix.dims(m)
            out.append(Item(name: "[\(k)]", category: store.complexMatrices[k] != nil ? "Complex" : "Matrix", bytes: 12 + (store.complexMatrices[k] != nil ? 18 : 9) * r * c))
        }
        for n in [1, 2, 3, 4, 5, 6, 7, 8, 9, 0] where !(store.yFuncs[n] ?? "").isEmpty {
            out.append(Item(name: "Y\(n)", category: "Y-Vars", bytes: 9 + (store.yFuncs[n]?.count ?? 0)))
        }
        for (k, v) in store.funcs.sorted(by: { $0.key < $1.key }) where !v.isEmpty {
            out.append(Item(name: k, category: "Y-Vars", bytes: 9 + v.count))
        }
        for (k, v) in store.programs.sorted(by: { $0.key < $1.key }) {
            out.append(Item(name: "prgm" + k, category: "Prgm", bytes: 9 + v.reduce(0) { $0 + $1.count + 1 }))
        }
        for (k, v) in store.pics.sorted(by: { $0.key < $1.key }) { out.append(Item(name: "Pic\(k)", category: "Pic", bytes: 767 + 8 * v.count)) }
        for (k, _) in store.gdbs.sorted(by: { $0.key < $1.key }) { out.append(Item(name: "GDB\(k)", category: "GDB", bytes: 178)) }
        for (k, v) in store.strings.sorted(by: { $0.key < $1.key }) { out.append(Item(name: "Str\(k)", category: "String", bytes: 9 + v.count)) }
        for (k, _) in store.groups.sorted(by: { $0.key < $1.key }) { out.append(Item(name: "group " + k, category: "Group", bytes: 512)) }
        return out
    }

    static func ramFree(_ store: VariableStore) -> Int {
        let used = items(store).filter { !store.archived.contains($0.name) }.reduce(0) { $0 + $1.bytes }
        return max(0, ramTotal - used - store.entries.reduce(0) { $0 + $1.count })
    }

    static func arcFree(_ store: VariableStore) -> Int {
        let used = items(store).filter { store.archived.contains($0.name) }.reduce(0) { $0 + $1.bytes }
        return max(0, arcTotal - used)
    }

    static func arcFreeText(_ store: VariableStore) -> String { "\(arcFree(store) / 1000)K" }
}
