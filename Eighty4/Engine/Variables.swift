import Foundation
import Observation

enum Drawing: Equatable, Codable {
    case line(Double, Double, Double, Double)
    case circle(Double, Double, Double)
    case point(Double, Double)
    case horizontal(Double)
    case vertical(Double)
    case function(String)
    case text(Double, Double, String)
    /// Pixel in TI graph coordinates (row 0…164, col 0…264).
    case pixel(Double, Double)
    /// Tangent to `expr` at x.
    case tangent(String, Double)
    /// Shade between lower and upper expressions, optionally limited to [xl, xr].
    case shade(String, String, Double?, Double?)
    /// Inverse of a function (x and y swapped).
    case inverse(String)
    /// Shaded distribution: kind (norm/t/chi2/F), parameters, lower, upper, caption.
    case dist(String, [Double], Double, Double, String)
}

enum GraphType: Int {
    case function = 0, parametric, polar, sequence
}

/// Everything ZoomSto/StoreGDB need to bring a graph back.
struct GraphDatabase: Codable, Equatable {
    var graph: Int
    var yFuncs: [String: String]
    var funcs: [String: String]
    var numbers: [String: Double]
    var options: [String: Int]
}

/// A MEM group: a snapshot of variables that can be ungrouped later.
struct VariableGroup: Codable, Equatable {
    var reals: [String: Double]
    var lists: [String: [Double]]
    var matrices: [String: [[Double]]]
    var yFuncs: [String: String]
    var funcs: [String: String]
    var strings: [String: String]
    var programs: [String: [String]]
}

/// All calculator memory: variables, lists, matrices, Y= functions, MODE/FORMAT options,
/// window/table numbers, stat results, and the entry history. Persisted to UserDefaults.
@Observable
final class VariableStore {
    static var persistenceEnabled = true

    var reals: [String: Double] = [:]
    var lists: [String: [Double]] = ["L1": [], "L2": [], "L3": [], "L4": [], "L5": [], "L6": []]
    var matrices: [String: [[Double]]] = [:]
    var yFuncs: [Int: String] = [:]
    var yEnabled: [Int: Bool] = [:]
    /// Parametric (X1T/Y1T…), polar (r1…) and sequence (u v w, u(nMin)…) definitions.
    var funcs: [String: String] = [:]
    var funcsEnabled: [String: Bool] = [:]
    var strings: [Int: String] = [:]
    var pics: [Int: [Drawing]] = [:]
    var gdbs: [Int: GraphDatabase] = [:]
    var programs: [String: [String]] = [:]
    var archived: Set<String> = []
    var groups: [String: VariableGroup] = [:]
    var sheet: [String: String] = [:]
    var solverEqn = ""
    var ans: Value = .num(0)
    var entries: [String] = []
    var options: [String: Int] = VariableStore.defaultOptions
    var numbers: [String: Double] = VariableStore.defaultNumbers
    var stats: [String: Double] = [:]
    var regEQ = ""
    var drawings: [Drawing] = []
    var previousWindow: [String: Double] = [:]
    var storedWindow: [String: Double] = [:]
    var lastKey = 0

    // Transient flags consumed by the key handler after an evaluation.
    var pendingClrHome = false
    var pendingShowGraph = false
    var pendingResults: [String]? = nil

    /// Temporary variable values (X, T, θ, n) used while sampling functions. Not observed,
    /// so views can evaluate functions during rendering without invalidating themselves.
    @ObservationIgnored var overrides: [String: Double] = [:]
    @ObservationIgnored var seqCache: [String: [Int: Double]] = [:]
    @ObservationIgnored var seqCacheKey = ""

    var xOverride: Double? {
        get { overrides["X"] }
        set { overrides["X"] = newValue }
    }

    static let defaultOptions: [String: Int] = [
        "plot1On": 1, "plot2On": 1, "plot3On": 1,
        "plot1Y": 1, "plot2Y": 1, "plot3Y": 1,
        "t.Ylist": 1, "t.List2": 1, "t.Exp": 1, "t.ExpL": 1,
    ]

    static let defaultNumbers: [String: Double] = [
        "Xmin": -10, "Xmax": 10, "Xscl": 1, "Ymin": -10, "Ymax": 10, "Yscl": 1, "Xres": 1,
        "Tmin": 0, "Tmax": 2 * .pi, "Tstep": .pi / 24,
        "θmin": 0, "θmax": 2 * .pi, "θstep": .pi / 24,
        "nMin": 1, "nMax": 10, "PlotStart": 1, "PlotStep": 1,
        "TblStart": 0, "ΔTbl": 1, "XFact": 4, "YFact": 4,
        "N": 0, "I%": 0, "PV": 0, "PMT": 0, "FV": 0, "P/Y": 1, "C/Y": 1,
        "t.C-Level": 0.95, "t.Freq": 1, "t.Freq1": 1, "t.Freq2": 1,
    ]

    init() { load() }

    // MARK: - Settings accessors

    var degrees: Bool { options["angle", default: 0] == 1 }
    var notation: Int { options["notation", default: 0] }
    var fixedDigits: Int? {
        let f = options["float", default: 0]
        return f == 0 ? nil : f - 1
    }
    var mixedFractions: Bool { options["fraction", default: 0] == 1 }
    var graphType: GraphType { GraphType(rawValue: options["graph", default: 0]) ?? .function }
    var thickLines: Bool { options["line", default: 0] == 0 || options["line", default: 0] == 1 }
    var dottedLines: Bool { options["line", default: 0] == 1 || options["line", default: 0] == 3 }
    var axesOn: Bool { options["axes", default: 0] == 0 }
    var gridStyle: Int { options["grid", default: 0] }
    var coordOn: Bool { options["coordOn", default: 0] == 0 }
    var exprOn: Bool { options["expr", default: 0] == 0 }
    var labelOn: Bool { options["label", default: 0] == 1 }
    var backgroundColor: Int { options["background", default: 0] }

    func plotOn(_ i: Int) -> Bool { options["plot\(i)On", default: 1] == 0 }
    func isYEnabled(_ n: Int) -> Bool { yEnabled[n] ?? true }

    /// Text of any graphable definition: "Y1"…"Y0", "X1T", "Y1T", "r1", "u", "u(nMin)".
    func funcText(_ key: String) -> String? {
        if let n = Self.yIndex(key) { return yFuncs[n] }
        return funcs[key]
    }

    func setFuncText(_ key: String, _ text: String?) {
        let t = (text?.isEmpty ?? true) ? nil : text
        if let n = Self.yIndex(key) { yFuncs[n] = t } else { funcs[key] = t }
        seqCache = [:]
    }

    func funcEnabled(_ key: String) -> Bool {
        if let n = Self.yIndex(key) { return isYEnabled(n) }
        return funcsEnabled[key] ?? true
    }

    func setFuncEnabled(_ key: String, _ on: Bool) {
        if let n = Self.yIndex(key) { yEnabled[n] = on } else { funcsEnabled[key] = on }
    }

    static func yIndex(_ key: String) -> Int? {
        guard key.count == 2, key.hasPrefix("Y"), let n = Int(key.dropFirst()) else { return nil }
        return n
    }

    var statusText: String {
        let notationText = ["NORMAL", "SCI", "ENG"][min(2, notation)]
        let floatText = fixedDigits.map { String($0) } ?? "FLOAT"
        let complexText = ["REAL", "a+bi", "re^θi"][min(2, options["complex", default: 0])]
        let angleText = degrees ? "DEGREE" : "RADIAN"
        return "\(notationText) \(floatText) AUTO \(complexText) \(angleText) MP"
    }

    func lookupReal(_ name: String) -> Double {
        if let o = overrides[name] { return o }
        if Tokenizer.windowVars.contains(name) { return numbers[name] ?? 0 }
        if let s = stats[name] { return s }
        return reals[name] ?? 0
    }

    // MARK: - Graph databases / pictures / groups

    func graphDatabase() -> GraphDatabase {
        GraphDatabase(graph: options["graph", default: 0],
                      yFuncs: Dictionary(uniqueKeysWithValues: yFuncs.map { (String($0.key), $0.value) }),
                      funcs: funcs,
                      numbers: Dictionary(uniqueKeysWithValues: Tokenizer.windowVars.map { ($0, numbers[$0] ?? 0) }),
                      options: options.filter { ["graph", "line", "grid", "axes", "label", "expr", "coord", "coordOn"].contains($0.key) })
    }

    func recall(_ g: GraphDatabase) {
        yFuncs = Dictionary(uniqueKeysWithValues: g.yFuncs.compactMap { k, v in Int(k).map { ($0, v) } })
        funcs = g.funcs
        for (k, v) in g.numbers { numbers[k] = v }
        for (k, v) in g.options { options[k] = v }
        seqCache = [:]
    }

    func makeGroup() -> VariableGroup {
        VariableGroup(reals: reals, lists: lists, matrices: matrices,
                      yFuncs: Dictionary(uniqueKeysWithValues: yFuncs.map { (String($0.key), $0.value) }),
                      funcs: funcs,
                      strings: Dictionary(uniqueKeysWithValues: strings.map { (String($0.key), $0.value) }),
                      programs: programs)
    }

    func ungroup(_ g: VariableGroup) {
        reals.merge(g.reals) { $1 }
        lists.merge(g.lists) { $1 }
        matrices.merge(g.matrices) { $1 }
        for (k, v) in g.yFuncs { if let n = Int(k) { yFuncs[n] = v } }
        funcs.merge(g.funcs) { $1 }
        for (k, v) in g.strings { if let n = Int(k) { strings[n] = v } }
        programs.merge(g.programs) { $1 }
    }

    func reset() {
        reals = [:]
        lists = ["L1": [], "L2": [], "L3": [], "L4": [], "L5": [], "L6": []]
        matrices = [:]
        yFuncs = [:]
        yEnabled = [:]
        funcs = [:]
        funcsEnabled = [:]
        strings = [:]
        pics = [:]
        gdbs = [:]
        programs = [:]
        archived = []
        groups = [:]
        sheet = [:]
        solverEqn = ""
        ans = .num(0)
        entries = []
        options = Self.defaultOptions
        numbers = Self.defaultNumbers
        stats = [:]
        regEQ = ""
        drawings = []
        seqCache = [:]
        save()
    }

    /// Reset ARCHIVE: drops archived variables (and apps/groups when asked).
    func resetArchive(vars: Bool, apps: Bool) {
        if vars {
            for name in archived { deleteVariable(name) }
            archived = []
        }
        if apps { groups = [:] }
        save()
    }

    /// Deletes a variable by its MEM display name ("A", "L1", "[A]", "Y1", "prgmNAME", "Pic1", "GDB1", "Str1", "group NAME").
    func deleteVariable(_ name: String) {
        if name.hasPrefix("prgm") { programs.removeValue(forKey: String(name.dropFirst(4))) }
        else if name.hasPrefix("[") { matrices.removeValue(forKey: String(name.dropFirst().dropLast())) }
        else if name.hasPrefix("L"), let n = Int(name.dropFirst()), (1...6).contains(n) { lists[name] = [] }
        else if let n = Self.yIndex(name) { yFuncs.removeValue(forKey: n) }
        else if name.hasPrefix("Pic"), let n = Int(name.dropFirst(3)) { pics.removeValue(forKey: n) }
        else if name.hasPrefix("GDB"), let n = Int(name.dropFirst(3)) { gdbs.removeValue(forKey: n) }
        else if name.hasPrefix("Str"), let n = Int(name.dropFirst(3)) { strings.removeValue(forKey: n) }
        else if name.hasPrefix("group ") { groups.removeValue(forKey: String(name.dropFirst(6))) }
        else if funcs[name] != nil { funcs.removeValue(forKey: name) }
        else { reals.removeValue(forKey: name) }
        archived.remove(name)
    }

    // MARK: - Persistence

    private struct Snapshot: Codable {
        var reals: [String: Double]
        var lists: [String: [Double]]
        var matrices: [String: [[Double]]]
        var yFuncs: [String: String]
        var yEnabled: [String: Bool]
        var entries: [String]
        var options: [String: Int]
        var numbers: [String: Double]
        var stats: [String: Double]
        var regEQ: String
        var funcs: [String: String]?
        var funcsEnabled: [String: Bool]?
        var strings: [String: String]?
        var pics: [String: [Drawing]]?
        var gdbs: [String: GraphDatabase]?
        var programs: [String: [String]]?
        var archived: [String]?
        var groups: [String: VariableGroup]?
        var sheet: [String: String]?
        var solverEqn: String?
    }

    private static let key = "eighty4.store"

    func save() {
        guard Self.persistenceEnabled else { return }
        let snap = Snapshot(
            reals: reals, lists: lists, matrices: matrices,
            yFuncs: Dictionary(uniqueKeysWithValues: yFuncs.map { (String($0.key), $0.value) }),
            yEnabled: Dictionary(uniqueKeysWithValues: yEnabled.map { (String($0.key), $0.value) }),
            entries: entries, options: options, numbers: numbers, stats: stats, regEQ: regEQ,
            funcs: funcs, funcsEnabled: funcsEnabled,
            strings: Dictionary(uniqueKeysWithValues: strings.map { (String($0.key), $0.value) }),
            pics: Dictionary(uniqueKeysWithValues: pics.map { (String($0.key), $0.value) }),
            gdbs: Dictionary(uniqueKeysWithValues: gdbs.map { (String($0.key), $0.value) }),
            programs: programs, archived: Array(archived), groups: groups, sheet: sheet, solverEqn: solverEqn
        )
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    func load() {
        guard Self.persistenceEnabled,
              let data = UserDefaults.standard.data(forKey: Self.key),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        func intKeyed<T>(_ d: [String: T]?) -> [Int: T] {
            Dictionary(uniqueKeysWithValues: (d ?? [:]).compactMap { k, v in Int(k).map { ($0, v) } })
        }
        reals = snap.reals
        lists = snap.lists
        matrices = snap.matrices
        yFuncs = intKeyed(snap.yFuncs)
        yEnabled = intKeyed(snap.yEnabled)
        entries = snap.entries
        options = Self.defaultOptions.merging(snap.options) { $1 }
        numbers = Self.defaultNumbers.merging(snap.numbers) { $1 }
        stats = snap.stats
        regEQ = snap.regEQ
        funcs = snap.funcs ?? [:]
        funcsEnabled = snap.funcsEnabled ?? [:]
        strings = intKeyed(snap.strings)
        pics = intKeyed(snap.pics)
        gdbs = intKeyed(snap.gdbs)
        programs = snap.programs ?? [:]
        archived = Set(snap.archived ?? [])
        groups = snap.groups ?? [:]
        sheet = snap.sheet ?? [:]
        solverEqn = snap.solverEqn ?? ""
    }

    static func wipe() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
