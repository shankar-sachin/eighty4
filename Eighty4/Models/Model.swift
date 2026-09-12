import SwiftUI

/// Which calculator the app is being: the TI-84 Plus CE replica or the TI-84 Evo replica.
/// The math engine is shared; the model picks the keypad, the body, the home screen and a few OS behaviours.
enum CalcModel: String, CaseIterable, Identifiable {
    case ce, evo

    var id: String { rawValue }

    /// Wordmark on the brand strip.
    var brand: String {
        switch self {
        case .ce: return "Eighty4+ CE"
        case .evo: return "Eighty4 Evo"
        }
    }

    var fullName: String {
        switch self {
        case .ce: return "TI-84 Plus CE"
        case .evo: return "TI-84 Evo"
        }
    }

    var shells: [ShellColor] { ShellColor.allCases.filter { $0.model == self } }

    var defaultShell: ShellColor {
        switch self {
        case .ce: return .black
        case .evo: return .white
        }
    }
}

/// The TI-84 Evo icon home screen: 3 rows of 4 icons plus TI-Basic and Help.
enum HomeIcon: Int, CaseIterable, Identifiable {
    case calculator, functionEditor, listEditor, mode
    case numericSolver, polyRootFinder, systemSolver, finance
    case transformation, inequality, linesConics, python
    case tiBasic, help

    var id: Int { rawValue }
    static let columns = 4

    var title: String {
        switch self {
        case .calculator: return "Calculator"
        case .functionEditor: return "Y= Editor"
        case .listEditor: return "List Editor"
        case .mode: return "Mode Settings"
        case .numericSolver: return "Numeric Solver"
        case .polyRootFinder: return "Poly Root Finder"
        case .systemSolver: return "System Solver"
        case .finance: return "Finance"
        case .transformation: return "Transformation"
        case .inequality: return "Inequality"
        case .linesConics: return "Lines & Conics"
        case .python: return "Python"
        case .tiBasic: return "TI-Basic"
        case .help: return "Help"
        }
    }

    /// Short caption under the icon.
    var caption: String {
        switch self {
        case .calculator: return "Calc"
        case .functionEditor: return "Y="
        case .listEditor: return "Lists"
        case .mode: return "Mode"
        case .numericSolver: return "Solver"
        case .polyRootFinder: return "PolyRoot"
        case .systemSolver: return "System"
        case .finance: return "Finance"
        case .transformation: return "Transfrm"
        case .inequality: return "Inequal"
        case .linesConics: return "Conics"
        case .python: return "Python"
        case .tiBasic: return "TI-Basic"
        case .help: return "Help"
        }
    }

    /// SF Symbol drawn inside the tile.
    var symbol: String {
        switch self {
        case .calculator: return "plus.forwardslash.minus"
        case .functionEditor: return "function"
        case .listEditor: return "tablecells"
        case .mode: return "slider.horizontal.3"
        case .numericSolver: return "equal.square"
        case .polyRootFinder: return "x.squareroot"
        case .systemSolver: return "square.grid.3x3"
        case .finance: return "dollarsign.circle"
        case .transformation: return "arrow.left.and.right"
        case .inequality: return "lessthanorequalto"
        case .linesConics: return "circle.and.line.horizontal"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .tiBasic: return "text.alignleft"
        case .help: return "questionmark.circle"
        }
    }

    /// Tile art colour: the Evo draws its icons in two inks, blue and green.
    var artColor: Color {
        switch self {
        case .calculator, .functionEditor, .numericSolver, .systemSolver, .transformation, .inequality, .tiBasic:
            return Color(hex: 0x1F5FBF)
        case .listEditor, .mode, .polyRootFinder, .finance, .linesConics, .python, .help:
            return Color(hex: 0x3FA34D)
        }
    }

    var row: Int { rawValue / Self.columns }
    var col: Int { rawValue % Self.columns }
}

/// TI-84 Evo Help app: quick tips, one screen per page (10 lines of 26 cells).
enum HelpPages {
    static let pages: [[String]] = [
        ["HELP  1/4  KEYS", "", "⌂ on  icon home screen;", "  again: Calculator app", "◂▸    fraction ↔ decimal", "n/d   fraction template", "x^□   any exponent", "2nd x^□  ⁿ√ root", "log   log of any base", "2nd clear  Undo clear"],
        ["HELP  2/4  TEMPLATES", "", "Empty boxes take input;", "▶ leaves a slot.", "DEL removes a whole", "template.", "◂▸ in a menu shows the", "syntax of a function.", "◂▸ in Y= shows the whole", "definition."],
        ["HELP  3/4  GRAPHING", "", "graph  draws Y1–Y0", "trace  ◀ ▶ walk a curve;", "  the cursor stops on", "  zeros, extrema,", "  intercepts and", "  intersections (POI).", "zoom 4  ZDecimal default", "2nd trace  CALC menu"],
        ["HELP  4/4  NAVIGATION", "", "alpha f1  FRAC menu", "alpha f2  FUNC menu", "alpha f3  MTRX menu", "alpha f4  YVAR menu", "2nd mode  quit", "2nd on    off", "", "◂▸ or clear  leaves Help"],
    ]
}

/// Calculators the app does not replicate yet, listed on the homepage so the roadmap is visible.
struct PlannedModel: Identifiable {
    /// The Eighty4 name, as it will appear on the wordmark.
    let brand: String
    /// The real calculator it replicates.
    let fullName: String
    let kind: String
    var id: String { brand }

    static let all: [PlannedModel] = [
        PlannedModel(brand: "Eighty4 30Xa", fullName: "TI-30Xa", kind: "Scientific"),
        PlannedModel(brand: "Eighty4 30XS", fullName: "TI-30XS MultiView", kind: "Scientific"),
        PlannedModel(brand: "Eighty4 36X Pro", fullName: "TI-36X Pro", kind: "Scientific"),
        PlannedModel(brand: "Eighty4+ SE", fullName: "TI-84 Plus Silver Edition", kind: "Graphing"),
        PlannedModel(brand: "Eighty4+", fullName: "TI-84 Plus", kind: "Graphing"),
        PlannedModel(brand: "Eighty4 Nspire", fullName: "TI-Nspire CX", kind: "Graphing"),
    ]
}

extension CalcModel {
    /// One line about the model, for the homepage card.
    var tagline: String {
        switch self {
        case .ce: return "The colour graphing classic. MathPrint, 10 functions, apps and TI-BASIC."
        case .evo: return "The 2026 flagship. Icon home screen, ◂▸ toggle key, Python and POI tracing."
        }
    }

    /// What the card lists under the tagline.
    var highlights: [String] {
        switch self {
        case .ce: return ["320×240 colour LCD", "MathPrint templates", "12 built-in apps", "TI-BASIC editor"]
        case .evo: return ["Icon home screen", "n/d, x^□ and ◂▸ keys", "Points-of-Interest trace", "Python shell"]
        }
    }
}
