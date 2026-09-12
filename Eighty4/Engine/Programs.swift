import Foundation

/// A resumable TI-BASIC interpreter. Programs run on the home screen; Input / Pause /
/// Menu( / getKey suspend execution until the key handler feeds the next key.
final class ProgramRunner {
    enum Wait: Equatable {
        case none
        case enter                       // Pause
        case input(String, String)       // (variable, prompt) — typed on the home screen
        case key                         // getKey with no key pending
        case menu(String, [String], [String])   // title, items, labels
    }

    private enum Block {
        case ifBlock
        case forLoop(String, Double, Double, Int)   // var, end, step, first body statement
        case whileLoop(String, Int)
        case repeatLoop(String, Int)
    }

    private struct Frame {
        let name: String
        let statements: [String]
        var pc = 0
        var blocks: [Block] = []
    }

    /// Interface the runner needs from the calculator.
    struct Host {
        let store: VariableStore
        let display: (String, Bool) -> Void        // text, trailing (right aligned)
        let output: (Int, Int, String) -> Void     // row, col, text
        let clearHome: () -> Void
        let showGraph: () -> Void
        let showTable: () -> Void
    }

    private var frames: [Frame] = []
    private let host: Host
    private(set) var wait: Wait = .none
    private var promptQueue: [String] = []
    private var steps = 0
    private(set) var lastValue: Value? = nil
    /// (program, statement index) of the statement that raised the last error.
    private(set) var errorLocation: (String, Int)? = nil
    private(set) var displayedSomething = false

    var isFinished: Bool { frames.isEmpty }
    var currentProgram: String? { frames.last?.name }

    init(host: Host) { self.host = host }

    static let keywords: Set<String> = ["Disp", "Input", "Prompt", "Output(", "Pause", "If", "Then", "Else", "For(", "While",
                                        "Repeat", "End", "Lbl", "Goto", "Menu(", "Return", "Stop", "DelVar", "IS>(", "DS<(",
                                        "DispGraph", "DispTable", "ClrHome", "Wait"]

    /// True if a home-screen entry should be run by the interpreter rather than the evaluator.
    static func isStatement(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("prgm") { return true }
        return keyword(of: t) != nil
    }

    static func keyword(of statement: String) -> String? {
        for k in keywords where statement.hasPrefix(k) {
            let rest = statement.dropFirst(k.count)
            if k.hasSuffix("(") { return k }
            if rest.isEmpty || rest.first == " " || !(rest.first!.isLetter) { return k }
        }
        return nil
    }

    /// Splits a program's lines into statements (":"-separated, quotes respected).
    static func statements(_ lines: [String]) -> [String] {
        var out: [String] = []
        for line in lines {
            var cur = ""
            var inString = false
            var depth = 0
            for ch in line {
                if ch == "\"" { inString.toggle() }
                if !inString { if ch == "(" || ch == "{" || ch == "[" { depth += 1 } else if ch == ")" || ch == "}" || ch == "]" { depth -= 1 } }
                if ch == ":" && !inString && depth <= 0 { out.append(cur); cur = ""; continue }
                cur.append(ch)
            }
            out.append(cur)
        }
        return out.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func splitArgs(_ text: String) -> [String] {
        var out: [String] = []
        var cur = ""
        var inString = false
        var depth = 0
        for ch in text {
            if ch == "\"" { inString.toggle() }
            if !inString {
                if ch == "(" || ch == "{" || ch == "[" { depth += 1 }
                if ch == ")" || ch == "}" || ch == "]" { depth -= 1 }
                if ch == "," && depth <= 0 { out.append(cur.trimmingCharacters(in: .whitespaces)); cur = ""; continue }
            }
            cur.append(ch)
        }
        let last = cur.trimmingCharacters(in: .whitespaces)
        if !last.isEmpty || !out.isEmpty { out.append(last) }
        return out
    }

    // MARK: - Running

    func start(program name: String) throws {
        guard let lines = host.store.programs[name] else { throw CalcError.undefined }
        frames.append(Frame(name: name, statements: Self.statements(lines)))
    }

    func start(lines: [String]) {
        frames.append(Frame(name: "", statements: Self.statements(lines)))
    }

    /// Feeds the key the runner was waiting for, then continues.
    func resume(input text: String?) throws {
        switch wait {
        case .input(let v, _):
            wait = .none
            if let text = text, !text.isEmpty {
                let value = try Evaluator.evaluate(text, ctx: EvalContext(store: host.store))
                try store(value, into: v)
            }
            if !promptQueue.isEmpty {
                let next = promptQueue.removeFirst()
                wait = .input(next, next + "=?")
                return
            }
        case .enter, .key:
            wait = .none
        case .menu(_, _, let labels):
            wait = .none
            if let text = text, let idx = Int(text), idx >= 1, idx <= labels.count { try goto(labels[idx - 1]) }
        case .none:
            break
        }
        try run()
    }

    func run() throws {
        steps = 0
        while let frame = frames.last, wait == .none {
            if frame.pc >= frame.statements.count {
                frames.removeLast()
                continue
            }
            steps += 1
            if steps > 2_000_000 { throw CalcError.breakKey }
            let idx = frames.count - 1
            let stmt = frames[idx].statements[frame.pc]
            frames[idx].pc += 1
            do {
                // `pc` passed to execute is the index of the *next* statement.
                try execute(stmt, at: frame.pc + 1)
            } catch let e as CalcError {
                errorLocation = (frame.name, frame.pc)
                throw e
            }
        }
        if frames.isEmpty, wait == .none, !displayedSomething, let v = lastValue {
            host.display(ResultFormatter.format(v, store: host.store), true)
        }
    }

    private func value(_ text: String) throws -> Value {
        try Evaluator.evaluate(text, ctx: EvalContext(store: host.store))
    }

    private func number(_ text: String) throws -> Double { try value(text).number() }

    private func store(_ v: Value, into name: String) throws {
        let tokens = try Tokenizer.tokenize(name)
        guard tokens.count == 1 else { throw CalcError.syntax }
        _ = try Evaluator.evaluate("\(text(for: v))→\(name)", ctx: EvalContext(store: host.store))
    }

    private func text(for v: Value) -> String {
        switch v {
        case .str(let s): return "\"\(s)\""
        default: return ResultFormatter.format(v, notation: 0, fixed: nil)
        }
    }

    private func goto(_ label: String) throws {
        guard !frames.isEmpty else { return }
        let idx = frames.count - 1
        if let target = frames[idx].statements.firstIndex(where: { $0 == "Lbl " + label || $0 == "Lbl" + label }) {
            frames[idx].pc = target + 1
            frames[idx].blocks = []
        } else {
            throw CalcError.label
        }
    }

    /// Index of the matching End (and the Else at the same depth, if any) for the block starting at `from`.
    private func blockEnd(from: Int) -> (elseIndex: Int?, endIndex: Int) {
        let stmts = frames.last!.statements
        var depth = 0
        var elseIndex: Int? = nil
        var i = from
        while i < stmts.count {
            let s = stmts[i]
            let k = Self.keyword(of: s)
            if k == "If" {
                if i + 1 < stmts.count, stmts[i + 1] == "Then" { depth += 1; i += 2; continue }
                i += 2; continue   // one-line If skips its own statement
            }
            if k == "For(" || k == "While" || k == "Repeat" { depth += 1 }
            else if k == "Else", depth == 0, elseIndex == nil { elseIndex = i }
            else if k == "End" {
                if depth == 0 { return (elseIndex, i) }
                depth -= 1
            }
            i += 1
        }
        return (elseIndex, stmts.count)
    }

    private func skipBlock() {
        let idx = frames.count - 1
        let (_, end) = blockEnd(from: frames[idx].pc)
        frames[idx].pc = end + 1
    }

    private func execute(_ stmt: String, at pc: Int) throws {
        if stmt.isEmpty { return }
        let idx = frames.count - 1
        if stmt.contains("getKey"), host.store.lastKey == 0, wait == .none {
            frames[idx].pc = pc - 1     // re-run this statement once a key arrives
            wait = .key
            return
        }
        defer { if stmt.contains("getKey") { host.store.lastKey = 0 } }

        if stmt.hasPrefix("prgm") {
            let name = String(stmt.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            guard host.store.programs[name] != nil else { throw CalcError.undefined }
            guard frames.count < 20 else { throw CalcError.undefined }
            try start(program: name)
            return
        }
        guard let k = Self.keyword(of: stmt) else {
            let v = try value(stmt)
            if case .str(let s) = v, s == "Done" {} else { host.store.ans = v }
            lastValue = v
            if host.store.pendingClrHome { host.store.pendingClrHome = false; host.clearHome() }
            if host.store.pendingShowGraph { host.store.pendingShowGraph = false; host.showGraph() }
            if let lines = host.store.pendingResults { host.store.pendingResults = nil; lines.forEach { host.display($0, false) }; displayedSomething = true }
            return
        }
        var rest = String(stmt.dropFirst(k.count)).trimmingCharacters(in: .whitespaces)
        if k.hasSuffix("("), rest.hasSuffix(")") { rest.removeLast() }
        let args = Self.splitArgs(rest)

        switch k {
        case "Disp":
            for a in args {
                let v = try value(a)
                if case .str(let s) = v { host.display(s, false) }
                else { host.display(ResultFormatter.format(v, store: host.store), true) }
            }
            displayedSomething = true
        case "Output(":
            guard args.count == 3 else { throw CalcError.argument }
            let v = try value(args[2])
            let s: String = { if case .str(let t) = v { return t }; return ResultFormatter.format(v, store: host.store) }()
            host.output(Int(try number(args[0])), Int(try number(args[1])), s)
            displayedSomething = true
        case "ClrHome":
            host.clearHome()
        case "Pause":
            if let a = args.first, !a.isEmpty {
                let v = try value(a)
                if case .str(let s) = v { host.display(s, false) } else { host.display(ResultFormatter.format(v, store: host.store), true) }
                displayedSomething = true
            }
            wait = .enter
        case "Wait":
            break
        case "Input":
            if args.isEmpty { wait = .input("X", "?"); return }
            if args.count == 2 {
                let p = try value(args[0])
                guard case .str(let prompt) = p else { throw CalcError.dataType }
                wait = .input(args[1], prompt)
            } else {
                wait = .input(args[0], "?")
            }
        case "Prompt":
            guard !args.isEmpty else { throw CalcError.argument }
            promptQueue = Array(args.dropFirst())
            wait = .input(args[0], args[0] + "=?")
        case "If":
            let cond = try number(rest) != 0
            let stmts = frames[idx].statements
            let nextIsThen = pc < stmts.count && stmts[pc] == "Then"
            if nextIsThen {
                if cond { frames[idx].pc = pc + 1; frames[idx].blocks.append(.ifBlock) }
                else {
                    let (elseIdx, endIdx) = blockEnd(from: pc + 1)
                    if let e = elseIdx { frames[idx].pc = e + 1; frames[idx].blocks.append(.ifBlock) }
                    else { frames[idx].pc = endIdx + 1 }
                }
            } else if !cond {
                frames[idx].pc = pc + 1
            }
        case "Then":
            break
        case "Else":
            // Reached after the true branch: skip to End.
            if case .ifBlock? = frames[idx].blocks.last { frames[idx].blocks.removeLast() }
            let (_, end) = blockEnd(from: pc)
            frames[idx].pc = end + 1
        case "End":
            guard let block = frames[idx].blocks.popLast() else { return }
            switch block {
            case .ifBlock: break
            case .forLoop(let v, let end, let step, let body):
                let cur = host.store.lookupReal(v) + step
                host.store.reals[v] = cur
                if (step > 0 && cur <= end) || (step < 0 && cur >= end) {
                    frames[idx].pc = body
                    frames[idx].blocks.append(block)
                }
            case .whileLoop(let cond, let body):
                if try number(cond) != 0 { frames[idx].pc = body; frames[idx].blocks.append(block) }
            case .repeatLoop(let cond, let body):
                if try number(cond) == 0 { frames[idx].pc = body; frames[idx].blocks.append(block) }
            }
        case "For(":
            guard args.count >= 3 else { throw CalcError.argument }
            let v = args[0]
            let start = try number(args[1]), end = try number(args[2])
            let step = args.count > 3 ? try number(args[3]) : 1
            guard step != 0 else { throw CalcError.argument }
            host.store.reals[v] = start
            if (step > 0 && start > end) || (step < 0 && start < end) { skipBlock() }
            else { frames[idx].blocks.append(.forLoop(v, end, step, pc)) }
        case "While":
            if try number(rest) != 0 { frames[idx].blocks.append(.whileLoop(rest, pc)) } else { skipBlock() }
        case "Repeat":
            frames[idx].blocks.append(.repeatLoop(rest, pc))
        case "Lbl":
            break
        case "Goto":
            try goto(rest)
        case "Menu(":
            guard args.count >= 3, args.count % 2 == 1 else { throw CalcError.argument }
            guard case .str(let title) = try value(args[0]) else { throw CalcError.dataType }
            var items: [String] = [], labels: [String] = []
            var i = 1
            while i + 1 < args.count {
                guard case .str(let item) = try value(args[i]) else { throw CalcError.dataType }
                items.append(item); labels.append(args[i + 1])
                i += 2
            }
            wait = .menu(title, items, labels)
        case "Return":
            frames.removeLast()
        case "Stop":
            frames = []
        case "DelVar":
            for a in args { host.store.reals.removeValue(forKey: a) }
        case "IS>(", "DS<(":
            guard args.count == 2 else { throw CalcError.argument }
            let v = args[0]
            let cur = host.store.lookupReal(v) + (k == "IS>(" ? 1 : -1)
            host.store.reals[v] = cur
            let limit = try number(args[1])
            if (k == "IS>(" && cur > limit) || (k == "DS<(" && cur < limit) { frames[idx].pc = pc + 1 }
        case "DispGraph":
            host.showGraph()
        case "DispTable":
            host.showTable()
        default:
            throw CalcError.syntax
        }
    }
}

/// TI getKey codes for the keypad.
enum KeyCodes {
    static func code(_ key: KeyID) -> Int {
        switch key {
        case .yEquals: return 11; case .window: return 12; case .zoom: return 13; case .trace: return 14; case .graph: return 15
        case .second: return 21; case .mode: return 22; case .del: return 23; case .left: return 24; case .up: return 25; case .right: return 26
        case .alpha: return 31; case .xtn: return 32; case .stat: return 33; case .down: return 34
        case .math: return 41; case .apps: return 42; case .prgm: return 43; case .vars: return 44; case .clear: return 45
        case .inverse: return 51; case .sin: return 52; case .cos: return 53; case .tan: return 54; case .power: return 55
        case .square: return 61; case .comma: return 62; case .lparen: return 63; case .rparen: return 64; case .divide: return 65
        case .log: return 71; case .seven: return 72; case .eight: return 73; case .nine: return 74; case .multiply: return 75
        case .ln: return 81; case .four: return 82; case .five: return 83; case .six: return 84; case .minus: return 85
        case .sto: return 91; case .one: return 92; case .two: return 93; case .three: return 94; case .plus: return 95
        case .on: return 0; case .zero: return 102; case .dot: return 103; case .negate: return 104; case .enter: return 105
        // TI-84 Evo keys report the code of the CE key at the same position.
        case .fraction: return 42; case .expTemplate: return 51; case .toggle: return 95
        }
    }
}
