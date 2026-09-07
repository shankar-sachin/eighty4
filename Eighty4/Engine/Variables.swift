import Foundation
import Observation

enum Drawing: Equatable {
    case line(Double, Double, Double, Double)
    case circle(Double, Double, Double)
    case point(Double, Double)
    case horizontal(Double)
    case vertical(Double)
    case function(String)
    case text(Double, Double, String)
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
    var ans: Value = .num(0)
    var entries: [String] = []
    var options: [String: Int] = VariableStore.defaultOptions
    var numbers: [String: Double] = VariableStore.defaultNumbers
    var stats: [String: Double] = [:]
    var regEQ = ""
    var drawings: [Drawing] = []
    var previousWindow: [String: Double] = [:]
    var storedWindow: [String: Double] = [:]

    // Transient flags consumed by the key handler after an evaluation.
    var pendingClrHome = false
    var pendingShowGraph = false

    /// Temporary X used while sampling Y= functions. Not observed, so views can
    /// evaluate functions during rendering without invalidating themselves.
    @ObservationIgnored var xOverride: Double? = nil

    static let defaultOptions: [String: Int] = [
        "plot1On": 1, "plot2On": 1, "plot3On": 1,
        "plot1Y": 1, "plot2Y": 1, "plot3Y": 1,
    ]

    static let defaultNumbers: [String: Double] = [
        "Xmin": -10, "Xmax": 10, "Xscl": 1, "Ymin": -10, "Ymax": 10, "Yscl": 1, "Xres": 1,
        "TblStart": 0, "ΔTbl": 1, "XFact": 4, "YFact": 4,
        "N": 0, "I%": 0, "PV": 0, "PMT": 0, "FV": 0, "P/Y": 1, "C/Y": 1,
    ]

    init() { load() }

    // MARK: - Settings accessors

    var degrees: Bool { options["angle", default: 0] == 1 }
    var notation: Int { options["notation", default: 0] }
    var fixedDigits: Int? {
        let f = options["float", default: 0]
        return f == 0 ? nil : f - 1
    }
    var thickLines: Bool { options["line", default: 0] == 0 || options["line", default: 0] == 1 }
    var dottedLines: Bool { options["line", default: 0] == 1 || options["line", default: 0] == 3 }
    var axesOn: Bool { options["axes", default: 0] == 0 }
    var gridStyle: Int { options["grid", default: 0] }
    var coordOn: Bool { options["coordOn", default: 0] == 0 }
    var exprOn: Bool { options["expr", default: 0] == 0 }
    var labelOn: Bool { options["label", default: 0] == 1 }

    func plotOn(_ i: Int) -> Bool { options["plot\(i)On", default: 1] == 0 }
    func isYEnabled(_ n: Int) -> Bool { yEnabled[n] ?? true }

    var statusText: String {
        let notationText = ["NORMAL", "SCI", "ENG"][min(2, notation)]
        let floatText = fixedDigits.map { String($0) } ?? "FLOAT"
        let complexText = ["REAL", "a+bi", "re^θi"][min(2, options["complex", default: 0])]
        let angleText = degrees ? "DEGREE" : "RADIAN"
        return "\(notationText) \(floatText) AUTO \(complexText) \(angleText) MP"
    }

    func lookupReal(_ name: String) -> Double {
        if name == "X", let x = xOverride { return x }
        if Tokenizer.windowVars.contains(name) { return numbers[name] ?? 0 }
        if let s = stats[name] { return s }
        return reals[name] ?? 0
    }

    func reset() {
        reals = [:]
        lists = ["L1": [], "L2": [], "L3": [], "L4": [], "L5": [], "L6": []]
        matrices = [:]
        yFuncs = [:]
        yEnabled = [:]
        ans = .num(0)
        entries = []
        options = Self.defaultOptions
        numbers = Self.defaultNumbers
        stats = [:]
        regEQ = ""
        drawings = []
        save()
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
    }

    private static let key = "eighty4.store"

    func save() {
        guard Self.persistenceEnabled else { return }
        let snap = Snapshot(
            reals: reals, lists: lists, matrices: matrices,
            yFuncs: Dictionary(uniqueKeysWithValues: yFuncs.map { (String($0.key), $0.value) }),
            yEnabled: Dictionary(uniqueKeysWithValues: yEnabled.map { (String($0.key), $0.value) }),
            entries: entries, options: options, numbers: numbers, stats: stats, regEQ: regEQ
        )
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    func load() {
        guard Self.persistenceEnabled,
              let data = UserDefaults.standard.data(forKey: Self.key),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        reals = snap.reals
        lists = snap.lists
        matrices = snap.matrices
        yFuncs = Dictionary(uniqueKeysWithValues: snap.yFuncs.compactMap { k, v in Int(k).map { ($0, v) } })
        yEnabled = Dictionary(uniqueKeysWithValues: snap.yEnabled.compactMap { k, v in Int(k).map { ($0, v) } })
        entries = snap.entries
        options = Self.defaultOptions.merging(snap.options) { $1 }
        numbers = Self.defaultNumbers.merging(snap.numbers) { $1 }
        stats = snap.stats
        regEQ = snap.regEQ
    }

    static func wipe() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
