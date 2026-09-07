import SwiftUI
import Observation

struct LCDLine: Identifiable {
    let id = UUID()
    var text: String
    var trailing: Bool
}

@Observable
final class CalculatorState {
    enum Modifier { case none, second, alpha, alphaLock }
    enum Screen: Equatable { case home, comingSoon, off, error(String) }

    static let columns = 26
    static let visibleRows = 10

    var entry: [Character] = []
    var cursor = 0
    var history: [LCDLine] = []
    var ans: Double = 0
    var lastEntry = ""
    var modifier: Modifier = .none
    var screen: Screen = .home
    var insertMode = false
    var showShellPicker = false

    var shell: ShellColor {
        didSet { UserDefaults.standard.set(shell.rawValue, forKey: "shell") }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "shell") ?? ""
        shell = ShellColor(rawValue: raw) ?? .black
    }

    // MARK: - Display model

    private var entryLineCount: Int { entry.count / Self.columns + 1 }

    /// The 10 lines currently visible on the home screen (history followed by the entry).
    var displayLines: [LCDLine] {
        var lines = history
        var chunks = Self.chunk(String(entry), Self.columns)
        while chunks.count < entryLineCount { chunks.append("") }
        lines += chunks.map { LCDLine(text: $0, trailing: false) }
        return Array(lines.suffix(Self.visibleRows))
    }

    /// Cursor position within the visible rows.
    var cursorCell: (row: Int, col: Int) {
        let total = history.count + entryLineCount
        let start = max(0, total - Self.visibleRows)
        return (history.count + cursor / Self.columns - start, cursor % Self.columns)
    }

    static func chunk(_ s: String, _ n: Int) -> [String] {
        var out: [String] = []
        var cur = ""
        for ch in s {
            cur.append(ch)
            if cur.count == n { out.append(cur); cur = "" }
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    // MARK: - Entry editing

    func insert(_ s: String) {
        guard entry.count + s.count <= Self.columns * 8 else { return }
        for ch in s {
            if !insertMode, cursor < entry.count {
                entry[cursor] = ch
            } else {
                entry.insert(ch, at: cursor)
            }
            cursor += 1
        }
    }

    func deleteAtCursor() {
        if entry.isEmpty { return }
        if cursor < entry.count {
            entry.remove(at: cursor)
        } else {
            entry.removeLast()
            cursor = entry.count
        }
    }

    func appendHistory(expr: String, result: String) {
        for c in Self.chunk(expr, Self.columns) {
            history.append(LCDLine(text: c, trailing: false))
        }
        history.append(LCDLine(text: result, trailing: true))
        if history.count > 80 { history.removeFirst(history.count - 80) }
    }

    func evaluate() {
        let text = entry.isEmpty ? lastEntry : String(entry)
        guard !text.isEmpty else { return }
        lastEntry = text
        do {
            let v = try Evaluator.evaluate(text, ans: ans)
            ans = v
            appendHistory(expr: text, result: ResultFormatter.format(v))
            entry = []
            cursor = 0
        } catch let err as CalcError {
            screen = .error(err.message)
        } catch {
            screen = .error("ERR:SYNTAX")
        }
    }
}
