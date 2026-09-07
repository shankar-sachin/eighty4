import Foundation

enum MenuID: Equatable {
    case math, test, angle, distr, list, vars, varsWindow, varsZoom, varsStats, varsTable, yvars, fnOnOff
    case matrix, stat, draw, prgm, apps, zoom, calc, mem, reset, link, statPlot, catalog
}

enum EditorID: Equatable {
    case mode, format, tblset, window, plot1, plot2, plot3, tvm
}

enum AppID: Equatable {
    case geoDash, tetris
}

enum CalcOp: Equatable {
    case value, zero, minimum, maximum, intersect, derivative, integral

    var prompts: [String] {
        switch self {
        case .value, .derivative: return ["X="]
        case .zero, .minimum, .maximum: return ["Left Bound?", "Right Bound?", "Guess?"]
        case .intersect: return ["First curve?", "Second curve?", "Guess?"]
        case .integral: return ["Lower Limit?", "Upper Limit?"]
        }
    }

    var label: String {
        switch self {
        case .value: return "Value"
        case .zero: return "Zero"
        case .minimum: return "Minimum"
        case .maximum: return "Maximum"
        case .intersect: return "Intersection"
        case .derivative: return "dy/dx"
        case .integral: return "∫f(x)dx"
        }
    }
}

enum GraphMode: Equatable {
    case view
    case trace
    case calc(CalcOp)
}

enum Screen: Equatable {
    case home
    case off
    case error(String)
    case menu(MenuID)
    case editor(EditorID)
    case yEquals
    case listEditor
    case matrixEditor(String)
    case graph
    case table
    case about
    case memMgmt
    case message([String])
    case linkReceive
    case app(AppID)
}

struct CalcResult: Equatable {
    var label: String
    var x: Double
    var y: Double
}

/// What a key press means after the 2nd/alpha modifier is applied.
enum KeyAction: Equatable {
    case insert(String)
    case openMenu(MenuID)
    case openEditor(EditorID)
    case openYEquals, openGraph, openTrace, openTable
    case enter, entry, clear, del, ins
    case left, right, up, down
    case rcl, on, none
}
