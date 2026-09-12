import SwiftUI

/// TI-84 Evo Python: a small shell. Arithmetic, `print(...)`, `import math`, `math.` functions, names
/// bound with `=` and the keypad's tokens are translated to the calculator engine, so `2**10`, `7/2`,
/// `math.sqrt(2)` and `x = 3` behave like Python; anything else reports a SyntaxError.
final class PythonApp: Game {
    let title = "PYTHON"
    private(set) var wantsExit = false
    let handlesClear = true

    private let store: VariableStore
    private var lines: [(text: String, output: Bool)] = [(text: "Python Shell  (Eighty4 Evo)", output: true), (text: "Type expressions; enter runs.", output: true)]
    private var field = AppField()
    private var names: [String: Double] = [:]

    init(store: VariableStore) { self.store = store }

    /// Newest line the shell printed (for tests).
    var lastOutput: String? { lines.last(where: { $0.output })?.text }

    func update(now: TimeInterval) {}
    func press(_ key: KeyID) {}

    func handle(_ key: KeyID, _ action: KeyAction) {
        switch action {
        case .insert(let s): _ = field.apply(.insert(Self.pythonToken(s)))
        case .del: _ = field.apply(.del)
        case .clear:
            if field.chars.isEmpty { wantsExit = true } else { field.chars = [] }
        case .enter: run(field.text); field.chars = []
        case .home, .on: wantsExit = true
        default: break
        }
    }

    /// Keypad tokens in Python spelling.
    static func pythonToken(_ s: String) -> String {
        switch s {
        case "×", "⋅": return "*"
        case "÷": return "/"
        case "^": return "**"
        case "⁻", "−": return "-"
        case "²": return "**2"
        case "√(": return "math.sqrt("
        case "π": return "math.pi"
        case "e": return "math.e"
        case "sin(", "cos(", "tan(", "log(": return "math." + s
        case "ln(": return "math.log("
        case "Ans": return "_"
        default: return s.lowercased() == s ? s : (s.count == 1 ? s.lowercased() : s)
        }
    }

    private func run(_ src: String) {
        let line = src.trimmingCharacters(in: .whitespaces)
        lines.append((text: ">>> " + line, output: false))
        guard !line.isEmpty else { return }
        if line.hasPrefix("import ") || line.hasPrefix("from ") { return }
        var expr = line
        var target: String? = nil
        if let eq = line.firstIndex(of: "="), !line.contains("==") {
            let lhs = line[..<eq].trimmingCharacters(in: .whitespaces)
            if !lhs.isEmpty, lhs.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
                target = lhs
                expr = String(line[line.index(after: eq)...])
            }
        }
        var printing = false
        if expr.hasPrefix("print(") && expr.hasSuffix(")") {
            printing = true
            expr = String(expr.dropFirst(6).dropLast())
        }
        do {
            let v = try evaluate(expr)
            if let t = target { names[t] = v; return }
            let text = Self.format(v)
            names["_"] = v
            lines.append((text: text, output: true))
            _ = printing
        } catch {
            lines.append((text: "SyntaxError: invalid syntax", output: true))
        }
        if lines.count > 40 { lines.removeFirst(lines.count - 40) }
    }

    /// Python spelling → calculator engine spelling.
    private func evaluate(_ python: String) throws -> Double {
        var s = python.trimmingCharacters(in: .whitespaces)
        for (name, value) in names.sorted(by: { $0.key.count > $1.key.count }) {
            s = s.replacingOccurrences(of: name, with: "(" + ResultFormatter.number(value) + ")")
        }
        let table: [(String, String)] = [("math.sqrt(", "√("), ("math.pi", "π"), ("math.e", "e"), ("math.log10(", "log("), ("math.log(", "ln("), ("math.sin(", "sin("), ("math.cos(", "cos("), ("math.tan(", "tan("), ("math.fabs(", "abs("), ("math.floor(", "int("), ("**", "^"), ("*", "×"), ("/", "÷")]
        for (py, ti) in table { s = s.replacingOccurrences(of: py, with: ti) }
        // A minus that starts a number is negation for the engine.
        var out = ""
        var prev: Character? = nil
        for c in s {
            if c == "-", prev == nil || "(,×÷^+−".contains(prev!) { out.append("⁻") } else if c == "-" { out.append("−") } else { out.append(c) }
            if c != " " { prev = c }
        }
        guard let v = try Evaluator.evaluate(out, ctx: EvalContext(store: store)).asDouble else { throw CalcError.dataType }
        return v
    }

    static func format(_ v: Double) -> String {
        if v.rounded() == v, abs(v) < 1e15 { return String(Int(v)) }
        return ResultFormatter.number(v)
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
        let visible = Array(lines.suffix(AppUI.rows - 1))
        for (i, l) in visible.enumerated() {
            AppUI.text(&ctx, String(l.text.prefix(AppUI.cols)), row: i, col: 0, color: l.output ? Color(hex: 0x1B7A3A) : .black)
        }
        let prompt = ">>> " + field.text
        AppUI.text(&ctx, String(prompt.suffix(AppUI.cols)), row: visible.count, col: 0)
        let cx = AppUI.leftPad + CGFloat(min(AppUI.cols, prompt.count)) * AppUI.cellW
        ctx.fill(Path(CGRect(x: cx, y: CGFloat(visible.count) * AppUI.lineH + 2, width: 2, height: AppUI.lineH - 4)), with: .color(Color(hex: 0x1F6FE0)))
    }
}
