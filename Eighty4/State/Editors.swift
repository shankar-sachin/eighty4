import Foundation

struct SettingRow {
    let key: String
    let label: String?
    let options: [String]
}

enum EditorRow {
    case options(SettingRow)
    case number(key: String, label: String)
}

struct EditorDef {
    let title: String?
    let rows: [EditorRow]
}

enum Editors {
    static func def(_ id: EditorID, store: VariableStore) -> EditorDef {
        switch id {
        case .mode:
            return EditorDef(title: nil, rows: [
                .options(SettingRow(key: "mathprint", label: nil, options: ["MATHPRINT", "CLASSIC"])),
                .options(SettingRow(key: "notation", label: nil, options: ["NORMAL", "SCI", "ENG"])),
                .options(SettingRow(key: "float", label: nil, options: ["FLOAT", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"])),
                .options(SettingRow(key: "angle", label: nil, options: ["RADIAN", "DEGREE"])),
                .options(SettingRow(key: "graph", label: nil, options: ["FUNCTION", "PARAM", "POLAR", "SEQ"])),
                .options(SettingRow(key: "line", label: nil, options: ["THICK", "DOT-THK", "THIN", "DOT-THN"])),
                .options(SettingRow(key: "seq", label: nil, options: ["SEQUENTIAL", "SIMUL"])),
                .options(SettingRow(key: "complex", label: nil, options: ["REAL", "a+bi", "re^θi"])),
                .options(SettingRow(key: "screen", label: nil, options: ["FULL", "HORIZ", "GRAPH-TABLE"])),
                .options(SettingRow(key: "fraction", label: "FRACTION TYPE:", options: ["n/d", "Un/d"])),
                .options(SettingRow(key: "answers", label: "ANSWERS:", options: ["AUTO", "DEC", "FRAC"])),
                .options(SettingRow(key: "statdiag", label: "STAT DIAGNOSTICS:", options: ["OFF", "ON"])),
                .options(SettingRow(key: "statwiz", label: "STAT WIZARDS:", options: ["ON", "OFF"])),
            ])
        case .format:
            return EditorDef(title: nil, rows: [
                .options(SettingRow(key: "coord", label: nil, options: ["RECTGC", "POLARGC"])),
                .options(SettingRow(key: "coordOn", label: nil, options: ["CoordOn", "CoordOff"])),
                .options(SettingRow(key: "grid", label: nil, options: ["GridOff", "GridDot", "GridLine"])),
                .options(SettingRow(key: "axes", label: nil, options: ["AxesOn", "AxesOff"])),
                .options(SettingRow(key: "label", label: nil, options: ["LabelOff", "LabelOn"])),
                .options(SettingRow(key: "expr", label: nil, options: ["ExprOn", "ExprOff"])),
                .options(SettingRow(key: "border", label: "BorderColor:", options: ["1", "2", "3", "4"])),
                .options(SettingRow(key: "asym", label: "Detect Asymptotes:", options: ["On", "Off"])),
            ])
        case .tblset:
            return EditorDef(title: "TABLE SETUP", rows: [
                .number(key: "TblStart", label: "TblStart"),
                .number(key: "ΔTbl", label: "ΔTbl"),
                .options(SettingRow(key: "indpnt", label: "Indpnt:", options: ["Auto", "Ask"])),
                .options(SettingRow(key: "depend", label: "Depend:", options: ["Auto", "Ask"])),
            ])
        case .window:
            let xy: [EditorRow] = [
                .number(key: "Xmin", label: "Xmin"), .number(key: "Xmax", label: "Xmax"), .number(key: "Xscl", label: "Xscl"),
                .number(key: "Ymin", label: "Ymin"), .number(key: "Ymax", label: "Ymax"), .number(key: "Yscl", label: "Yscl"),
            ]
            switch store.graphType {
            case .function:
                return EditorDef(title: "WINDOW", rows: xy + [.number(key: "Xres", label: "Xres")])
            case .parametric:
                return EditorDef(title: "WINDOW", rows: [.number(key: "Tmin", label: "Tmin"), .number(key: "Tmax", label: "Tmax"), .number(key: "Tstep", label: "Tstep")] + xy)
            case .polar:
                return EditorDef(title: "WINDOW", rows: [.number(key: "θmin", label: "θmin"), .number(key: "θmax", label: "θmax"), .number(key: "θstep", label: "θstep")] + xy)
            case .sequence:
                return EditorDef(title: "WINDOW", rows: [.number(key: "nMin", label: "nMin"), .number(key: "nMax", label: "nMax"), .number(key: "PlotStart", label: "PlotStart"), .number(key: "PlotStep", label: "PlotStep")] + xy)
            }
        case .plot1, .plot2, .plot3:
            let i = id == .plot1 ? 1 : (id == .plot2 ? 2 : 3)
            return EditorDef(title: "Plot\(i)", rows: [
                .options(SettingRow(key: "plot\(i)On", label: nil, options: ["On", "Off"])),
                .options(SettingRow(key: "plot\(i)Type", label: "Type:", options: ["Scat", "xyLn", "Hist", "Box"])),
                .options(SettingRow(key: "plot\(i)X", label: "Xlist:", options: ["L1", "L2", "L3", "L4", "L5", "L6"])),
                .options(SettingRow(key: "plot\(i)Y", label: "Ylist:", options: ["L1", "L2", "L3", "L4", "L5", "L6"])),
                .options(SettingRow(key: "plot\(i)Mark", label: "Mark:", options: ["□", "+", "·"])),
                .options(SettingRow(key: "plot\(i)Color", label: "Color:", options: ["BLUE", "RED", "BLACK", "MAGENTA", "GREEN"])),
            ])
        case .tvm:
            return EditorDef(title: nil, rows: [
                .number(key: "N", label: "N"), .number(key: "I%", label: "I%"), .number(key: "PV", label: "PV"),
                .number(key: "PMT", label: "PMT"), .number(key: "FV", label: "FV"),
                .number(key: "P/Y", label: "P/Y"), .number(key: "C/Y", label: "C/Y"),
                .options(SettingRow(key: "pmtTiming", label: "PMT:", options: ["END", "BEGIN"])),
            ])
        case .zoomFactors:
            return EditorDef(title: "ZOOM FACTORS", rows: [.number(key: "XFact", label: "XFact"), .number(key: "YFact", label: "YFact")])
        case .statTest(let t):
            return EditorDef(title: t.title, rows: t.rows(store: store))
        }
    }
}
