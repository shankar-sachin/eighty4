import Foundation

enum Command: Equatable {
    case zoom(ZoomKind)
    case clearEntries, resetAll, resetDefaults, about, memMgmt
    case oneVar, twoVar, linReg, linRegAlt, quadReg, cubicReg, quartReg, expReg, lnReg, pwrReg, medMed
    case listEditor, matrixEdit(String), programsReadOnly
    case calc(CalcOp), trace
    case linkSend, linkReceive
    case clrDraw, insertRegEQ
    case notAvailable(String)
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
    private static func na(_ label: String) -> MenuItem { MenuItem(label: label, action: .command(.notAvailable(label))) }
    private static func sub(_ label: String, _ id: MenuID) -> MenuItem { MenuItem(label: label, action: .submenu(id)) }

    static func def(_ id: MenuID, store: VariableStore) -> MenuDef {
        let subs = Tokenizer.subscripts
        switch id {
        case .math:
            return MenuDef(tabs: [
                MenuTab(title: "MATH", items: [ins("▶Frac"), ins("▶Dec"), ins("³"), ins("³√("), ins("ˣ√"), ins("fMin("), ins("fMax("), ins("nDeriv("), ins("fnInt("), ins("Σ("), ins("logBASE("), na("Solver…")]),
                MenuTab(title: "NUM", items: [ins("abs("), ins("round("), ins("iPart("), ins("fPart("), ins("int("), ins("min("), ins("max("), ins("lcm("), ins("gcd("), ins("remainder(")]),
                MenuTab(title: "CMPLX", items: [ins("conj("), ins("real("), ins("imag("), ins("angle("), ins("abs("), ins("▶Rect"), ins("▶Polar")]),
                MenuTab(title: "PROB", items: [ins("rand"), ins("nPr", " nPr "), ins("nCr", " nCr "), ins("!"), ins("randInt("), ins("randNorm("), ins("randBin("), ins("randIntNoRep(")]),
                MenuTab(title: "FRAC", items: [ins("n/d", "/"), na("Un/d"), ins("▶n/d◀▶Un/d"), ins("▶F◀▶D")]),
            ])
        case .test:
            return MenuDef(tabs: [
                MenuTab(title: "TEST", items: [ins("="), ins("≠"), ins(">"), ins("≥"), ins("<"), ins("≤")]),
                MenuTab(title: "LOGIC", items: [ins("and", " and "), ins("or", " or "), ins("xor", " xor "), ins("not(")]),
            ])
        case .angle:
            return MenuDef(tabs: [MenuTab(title: "ANGLE", items: [ins("°"), ins("'"), ins("ʳ"), ins("▶DMS"), ins("R▶Pr("), ins("R▶Pθ("), ins("P▶Rx("), ins("P▶Ry(")])])
        case .distr:
            return MenuDef(tabs: [
                MenuTab(title: "DISTR", items: [ins("normalpdf("), ins("normalcdf("), ins("invNorm("), ins("invT("), ins("tpdf("), ins("tcdf("), ins("χ²pdf("), ins("χ²cdf("), ins("Fpdf("), ins("Fcdf("), ins("binompdf("), ins("binomcdf("), ins("poissonpdf("), ins("poissoncdf("), ins("geometpdf("), ins("geometcdf(")]),
                MenuTab(title: "DRAW", items: [na("ShadeNorm("), na("Shade_t("), na("Shadeχ²("), na("ShadeF(")]),
            ])
        case .list:
            return MenuDef(tabs: [
                MenuTab(title: "NAMES", items: (1...6).map { ins("L\(subs[$0])") }),
                MenuTab(title: "OPS", items: [ins("SortA("), ins("SortD("), ins("dim("), na("Fill("), ins("seq("), ins("cumSum("), ins("ΔList("), ins("augment(")]),
                MenuTab(title: "MATH", items: [ins("min("), ins("max("), ins("mean("), ins("median("), ins("sum("), ins("prod("), ins("stdDev("), ins("variance(")]),
            ])
        case .vars:
            return MenuDef(tabs: [
                MenuTab(title: "VARS", items: [sub("Window…", .varsWindow), sub("Zoom…", .varsZoom), na("GDB…"), na("Picture…"), sub("Statistics…", .varsStats), sub("Table…", .varsTable), na("String…")]),
                MenuTab(title: "Y-VARS", items: [sub("Function…", .yvars), na("Parametric…"), na("Polar…"), sub("On/Off…", .fnOnOff)]),
            ])
        case .varsWindow:
            return MenuDef(tabs: [
                MenuTab(title: "X/Y", items: [ins("Xmin"), ins("Xmax"), ins("Xscl"), ins("Ymin"), ins("Ymax"), ins("Yscl"), ins("Xres")]),
                MenuTab(title: "T/θ", items: [na("Tmin"), na("Tmax"), na("Tstep"), na("θmin"), na("θmax"), na("θstep")]),
            ])
        case .varsZoom:
            return MenuDef(tabs: [MenuTab(title: "ZX/ZY", items: [ins("XFact"), ins("YFact")])])
        case .varsStats:
            return MenuDef(tabs: [
                MenuTab(title: "XY", items: [ins("n"), ins("x̄"), ins("Sx"), ins("σx"), ins("ȳ"), ins("Sy"), ins("σy"), ins("minX"), ins("maxX"), ins("minY"), ins("maxY")]),
                MenuTab(title: "Σ", items: [ins("Σx"), ins("Σx²"), ins("Σy"), ins("Σy²"), ins("Σxy")]),
                MenuTab(title: "EQ", items: [cmd("RegEQ", .insertRegEQ), ins("a"), ins("b"), ins("c"), ins("d"), ins("r"), ins("r²")]),
                MenuTab(title: "PTS", items: [ins("Q1"), ins("Med"), ins("Q3")]),
            ])
        case .varsTable:
            return MenuDef(tabs: [MenuTab(title: "TABLE", items: [ins("TblStart"), ins("ΔTbl")])])
        case .yvars:
            return MenuDef(tabs: [MenuTab(title: "FUNCTION", items: (0...9).map { i in let n = i == 9 ? 0 : i + 1; return ins("Y\(subs[n])") })])
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
                MenuTab(title: "MATH", items: [ins("det("), ins("ᵀ"), ins("dim("), na("Fill("), ins("identity("), ins("randM("), ins("augment("), na("Matr▶list("), na("List▶matr("), ins("cumSum("), ins("ref("), ins("rref("), na("rowSwap("), na("row+("), na("*row("), na("*row+(")]),
                MenuTab(title: "EDIT", items: letters.map { cmd(nameLabel($0), .matrixEdit($0)) }),
            ])
        case .stat:
            return MenuDef(tabs: [
                MenuTab(title: "EDIT", items: [cmd("Edit…", .listEditor), ins("SortA("), ins("SortD("), ins("ClrList", "ClrList "), ins("SetUpEditor")]),
                MenuTab(title: "CALC", items: [cmd("1-Var Stats", .oneVar), cmd("2-Var Stats", .twoVar), cmd("Med-Med", .medMed), cmd("LinReg(ax+b)", .linReg), cmd("QuadReg", .quadReg), cmd("CubicReg", .cubicReg), cmd("QuartReg", .quartReg), cmd("LinReg(a+bx)", .linRegAlt), cmd("LnReg", .lnReg), cmd("ExpReg", .expReg), cmd("PwrReg", .pwrReg), na("Logistic"), na("SinReg")]),
                MenuTab(title: "TESTS", items: ["Z-Test…", "T-Test…", "2-SampZTest…", "2-SampTTest…", "1-PropZTest…", "2-PropZTest…", "ZInterval…", "TInterval…", "2-SampZInt…", "2-SampTInt…", "1-PropZInt…", "2-PropZInt…", "χ²-Test…", "χ²GOF-Test…", "2-SampFTest…", "LinRegTTest…", "LinRegTInt…", "ANOVA("].map(na)),
            ])
        case .draw:
            return MenuDef(tabs: [
                MenuTab(title: "DRAW", items: [cmd("ClrDraw", .clrDraw), ins("Line("), ins("Horizontal", "Horizontal "), ins("Vertical", "Vertical "), na("Tangent("), ins("DrawF", "DrawF "), na("Shade("), na("DrawInv"), ins("Circle("), ins("Text("), na("Pen")]),
                MenuTab(title: "POINTS", items: [ins("Pt-On("), na("Pt-Off("), na("Pt-Change("), na("Pxl-On("), na("Pxl-Off("), na("Pxl-Change("), na("pxl-Test(")]),
                MenuTab(title: "STO", items: [na("StorePic"), na("RecallPic"), na("StoreGDB"), na("RecallGDB")]),
                MenuTab(title: "BACKGROUND", items: [na("BackgroundOn"), na("BackgroundOff")]),
            ])
        case .prgm:
            return MenuDef(tabs: [
                MenuTab(title: "EXEC", items: [MenuItem(label: "GEODASH", action: .app(.geoDash)), MenuItem(label: "TETRIS", action: .app(.tetris))]),
                MenuTab(title: "EDIT", items: [cmd("GEODASH", .programsReadOnly), cmd("TETRIS", .programsReadOnly)]),
                MenuTab(title: "NEW", items: [cmd("Create New", .programsReadOnly)]),
            ])
        case .apps:
            return MenuDef(tabs: [MenuTab(title: "APPLICATIONS", items: [
                MenuItem(label: "GeoDash", action: .app(.geoDash)),
                MenuItem(label: "Tetris", action: .app(.tetris)),
                MenuItem(label: "Finance…", action: .editor(.tvm)),
                na("CabriJr"), na("CelSheet"), na("Conics"), na("Inequalz"), na("PlySmlt2"), na("Prob Sim"), na("SciTools"), na("Transfrm"), na("Vernier"),
            ])])
        case .zoom:
            return MenuDef(tabs: [
                MenuTab(title: "ZOOM", items: [na("ZBox"), cmd("Zoom In", .zoom(.zoomIn)), cmd("Zoom Out", .zoom(.zoomOut)), cmd("ZDecimal", .zoom(.decimal)), cmd("ZSquare", .zoom(.square)), cmd("ZStandard", .zoom(.standard)), cmd("ZTrig", .zoom(.trig)), cmd("ZInteger", .zoom(.integer)), cmd("ZoomStat", .zoom(.stat)), cmd("ZoomFit", .zoom(.fit)), cmd("ZQuadrant1", .zoom(.quadrant1)), na("ZFrac1/2"), na("ZFrac1/3"), na("ZFrac1/4")]),
                MenuTab(title: "MEMORY", items: [cmd("ZPrevious", .zoom(.previous)), cmd("ZoomSto", .zoom(.sto)), cmd("ZoomRcl", .zoom(.rcl)), na("SetFactors…")]),
            ])
        case .calc:
            return MenuDef(tabs: [MenuTab(title: "CALCULATE", items: [cmd("value", .calc(.value)), cmd("zero", .calc(.zero)), cmd("minimum", .calc(.minimum)), cmd("maximum", .calc(.maximum)), cmd("intersect", .calc(.intersect)), cmd("dy/dx", .calc(.derivative)), cmd("∫f(x)dx", .calc(.integral))])])
        case .mem:
            return MenuDef(tabs: [MenuTab(title: "MEMORY", items: [cmd("About", .about), cmd("Mem Management/Delete…", .memMgmt), cmd("Clear Entries", .clearEntries), ins("ClrAllLists"), na("Archive…"), na("UnArchive…"), sub("Reset…", .reset), na("Group…"), na("Garbage Collect…")])])
        case .reset:
            return MenuDef(tabs: [
                MenuTab(title: "RAM", items: [cmd("All RAM…", .resetAll), cmd("Defaults…", .resetDefaults)]),
                MenuTab(title: "ARCHIVE", items: [na("Vars…"), na("Apps…"), na("Both…")]),
                MenuTab(title: "ALL", items: [cmd("All Memory…", .resetAll)]),
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
            names += Tokenizer.postfixes.filter { $0 != "⁻¹" }
            names += ["and", "or", "xor", "nCr", "nPr", "rand", "Ans", "π", "e", "!", "°", "ʳ", "ᵀ", "²", "³", "ˣ√", "√(", "=", "≠", "≥", "≤", "→"]
            names = Array(Set(names)).sorted { $0.lowercased() < $1.lowercased() }
            return MenuDef(tabs: [MenuTab(title: "CATALOG", items: names.map { name in
                if name == "and" || name == "or" || name == "xor" || name == "nCr" || name == "nPr" { return ins(name, " \(name) ") }
                return ins(name)
            })])
        }
    }
}
