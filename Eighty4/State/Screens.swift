import Foundation

enum MenuID: Equatable {
    case math, test, angle, distr, list, vars, varsWindow, varsZoom, varsStats, varsTable, yvars, fnOnOff
    case varsGDB, varsPic, varsStr, yvarsParam, yvarsPolar, yvarsSeq
    case matrix, stat, draw, prgm, apps, zoom, calc, mem, reset, link, statPlot, catalog
    case memMgmt, group, prgmCtl
}

enum EditorID: Equatable {
    case mode, format, tblset, window, plot1, plot2, plot3, tvm, zoomFactors
    case statTest(StatTest)
}

enum AppID: Equatable {
    case geoDash, tetris
    case plySmlt2, conics, inequalz, probSim, sciTools, transfrm, celSheet, cabriJr, vernier
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
    case zbox      // ZOOM 1:ZBox — pick two corners
    case pen       // DRAW A:Pen — free-hand drawing
}

/// MEM variable lists: Archive / UnArchive toggle archive status; manage(category) deletes.
enum VarListMode: Equatable {
    case archive, unarchive
    case manage(String)
}

enum ConfirmKind: Equatable {
    case resetRAM, resetDefaults, resetArchiveVars, resetArchiveApps, resetArchiveBoth, garbageCollect
    case deleteVariable(String)

    var lines: [String] {
        switch self {
        case .resetRAM: return ["RESET RAM", "", "Resetting RAM erases all", "data, programs and apps", "from RAM.", "", "1:No", "2:Reset"]
        case .resetDefaults: return ["RESET DEFAULTS", "", "Resetting defaults", "restores every MODE,", "FORMAT and WINDOW", "setting.", "1:No", "2:Reset"]
        case .resetArchiveVars: return ["RESET ARC VARS", "", "Resetting ARCHIVE Vars", "erases all archived", "variables.", "", "1:No", "2:Reset"]
        case .resetArchiveApps: return ["RESET ARC APPS", "", "Resetting ARCHIVE Apps", "erases all apps and", "groups.", "", "1:No", "2:Reset"]
        case .resetArchiveBoth: return ["RESET ARC BOTH", "", "Resetting ARCHIVE Both", "erases all archived", "variables, apps and", "groups.", "1:No", "2:Reset"]
        case .garbageCollect: return ["", "Garbage Collect?", "", "1:No", "2:Yes"]
        case .deleteVariable(let n): return ["", "Delete \(n)?", "", "1:No", "2:Yes"]
        }
    }
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
    case message([String])
    case linkReceive
    case app(AppID)
    case solver
    case varList(VarListMode)
    case confirm(ConfirmKind)
    case programEditor(String)
    case programName
    case programMenu(String, [String])
    case groupName
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
