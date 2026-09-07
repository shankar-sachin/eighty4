import Foundation

struct EvalContext {
    let store: VariableStore
    var depth: Int = 0
}

/// Recursive-descent evaluator with TI-84 precedence (lowest → highest):
/// or/xor · and · comparisons · + − · × ÷ nCr nPr implicit · unary ⁻ · ^ ˣ√ · postfix · primary
struct Parser {
    private let tokens: [Token]
    private var pos = 0
    private let ctx: EvalContext

    init(tokens: [Token], ctx: EvalContext) {
        self.tokens = tokens
        self.ctx = ctx
    }

    private var peek: Token? { pos < tokens.count ? tokens[pos] : nil }
    private mutating func advance() { pos += 1 }

    mutating func parseStatement() throws -> Value {
        guard !tokens.isEmpty else { throw CalcError.syntax }
        if case .command(let name) = tokens[0] {
            advance()
            var args: [Token] = []
            while let t = peek { args.append(t); advance() }
            return try Commands.run(name, args: args, ctx: ctx)
        }
        let v = try expr()
        if peek == .store {
            advance()
            guard let target = peek else { throw CalcError.syntax }
            advance()
            if pos != tokens.count { throw CalcError.syntax }
            try storeValue(v, into: target)
            return v
        }
        if pos != tokens.count { throw CalcError.syntax }
        return v
    }

    private func storeValue(_ v: Value, into target: Token) throws {
        let store = ctx.store
        switch target {
        case .variable(let name):
            if Tokenizer.windowVars.contains(name) { store.numbers[name] = try v.number() }
            else { store.reals[name] = try v.number() }
        case .listVar(let name):
            store.lists[name] = try v.listValue()
        case .matVar(let name):
            store.matrices[name] = try v.matrixValue()
        case .yVar(let n):
            guard case .str(let s) = v else { throw CalcError.dataType }
            store.yFuncs[n] = s
        default:
            throw CalcError.syntax
        }
    }

    // MARK: - Precedence chain

    private mutating func expr() throws -> Value { try logicOr() }

    private mutating func logicOr() throws -> Value {
        var v = try logicAnd()
        while let t = peek {
            if case .op(let op) = t, op == .or || op == .xor {
                advance(); v = try Value.apply(op, v, try logicAnd())
            } else { break }
        }
        return v
    }

    private mutating func logicAnd() throws -> Value {
        var v = try comparison()
        while peek == .op(.and) {
            advance(); v = try Value.apply(.and, v, try comparison())
        }
        return v
    }

    private mutating func comparison() throws -> Value {
        var v = try additive()
        while let t = peek {
            if case .op(let op) = t, [.eq, .ne, .gt, .ge, .lt, .le].contains(op) {
                advance(); v = try Value.apply(op, v, try additive())
            } else { break }
        }
        return v
    }

    private mutating func additive() throws -> Value {
        var v = try term()
        while let t = peek {
            if case .op(let op) = t, op == .add || op == .sub {
                advance(); v = try Value.apply(op, v, try term())
            } else { break }
        }
        return v
    }

    private mutating func term() throws -> Value {
        var v = try unary()
        while let t = peek {
            if case .op(let op) = t, [.mul, .div, .nCr, .nPr].contains(op) {
                advance(); v = try Value.apply(op, v, try unary())
            } else if t.startsPrimary {
                v = try Value.apply(.mul, v, try unary())   // implicit multiplication
            } else { break }
        }
        return v
    }

    private mutating func unary() throws -> Value {
        if peek == .negate {
            advance()
            return try (try unary()).negated()
        }
        return try power()
    }

    private mutating func power() throws -> Value {
        let base = try postfix()
        if peek == .op(.pow) {
            advance()
            return try Value.apply(.pow, base, try unary())
        }
        if peek == .op(.nthRoot) {
            advance()
            return try Value.apply(.nthRoot, base, try unary())
        }
        return base
    }

    private mutating func postfix() throws -> Value {
        var v = try primary()
        while let t = peek, case .postfix(let p) = t {
            advance()
            v = try Postfix.apply(p, v, ctx)
        }
        return v
    }

    /// TI allows a missing ')' at the very end of the entry.
    private mutating func closeParen() throws {
        if peek == .rparen { advance(); return }
        if pos == tokens.count { return }
        throw CalcError.syntax
    }

    private mutating func primary() throws -> Value {
        guard let t = peek else { throw CalcError.syntax }
        let store = ctx.store
        switch t {
        case .number(let x): advance(); return .num(x)
        case .string(let s): advance(); return .str(s)
        case .pi: advance(); return .num(.pi)
        case .e: advance(); return .num(M_E)
        case .ans: advance(); return store.ans
        case .nullary(let name): advance(); return try Functions.call(name, [], ctx)
        case .variable(let name): advance(); return .num(store.lookupReal(name))
        case .listVar(let name):
            advance()
            guard let l = store.lists[name] else { throw CalcError.undefined }
            return .list(l)
        case .matVar(let name):
            advance()
            guard let m = store.matrices[name] else { throw CalcError.undefined }
            return .matrix(m)
        case .yVar(let n):
            advance()
            return try evalY(n)
        case .lparen:
            advance()
            let v = try expr()
            try closeParen()
            return v
        case .lbrace:
            advance()
            var items: [Double] = []
            if peek == .rbrace { advance(); return .list([]) }
            while true {
                items.append(try expr().number())
                if peek == .comma { advance(); continue }
                break
            }
            if peek == .rbrace { advance() } else if pos != tokens.count { throw CalcError.syntax }
            return .list(items)
        case .lbracket:
            advance()
            var rows: [[Double]] = []
            while peek == .lbracket {
                advance()
                var row: [Double] = []
                while true {
                    row.append(try expr().number())
                    if peek == .comma { advance(); continue }
                    break
                }
                guard peek == .rbracket else { throw CalcError.syntax }
                advance()
                rows.append(row)
            }
            if peek == .rbracket { advance() } else if pos != tokens.count { throw CalcError.syntax }
            guard !rows.isEmpty, Set(rows.map(\.count)).count == 1 else { throw CalcError.invalidDim }
            return .matrix(rows)
        case .function(let name):
            advance()
            guard peek == .lparen else { throw CalcError.syntax }
            advance()
            if Functions.lazyNames.contains(name) { return try callLazy(name) }
            var args: [Value] = []
            if peek == .rparen { advance(); return try Functions.call(name, args, ctx) }
            while true {
                args.append(try expr())
                if peek == .comma { advance(); continue }
                break
            }
            try closeParen()
            return try Functions.call(name, args, ctx)
        default:
            throw CalcError.syntax
        }
    }

    private func evalY(_ n: Int) throws -> Value {
        guard ctx.depth < 8 else { throw CalcError.undefined }
        guard let text = ctx.store.yFuncs[n], !text.isEmpty else { throw CalcError.undefined }
        var sub = EvalContext(store: ctx.store, depth: ctx.depth + 1)
        sub.depth = ctx.depth + 1
        var p = Parser(tokens: try Tokenizer.tokenize(text), ctx: sub)
        return try p.parseStatement()
    }

    // MARK: - Lazy (expression-taking) functions

    private mutating func collectArgSlices() throws -> [[Token]] {
        var slices: [[Token]] = []
        var cur: [Token] = []
        var depth = 0
        while let t = peek {
            advance()
            switch t {
            case .lparen, .lbrace, .lbracket:
                depth += 1; cur.append(t)
            case .rparen, .rbrace, .rbracket:
                if depth == 0 {
                    guard t == .rparen else { throw CalcError.syntax }
                    slices.append(cur)
                    return slices
                }
                depth -= 1; cur.append(t)
            case .comma where depth == 0:
                slices.append(cur); cur = []
            default:
                cur.append(t)
            }
        }
        slices.append(cur)
        return slices
    }

    private func evalSlice(_ slice: [Token]) throws -> Double {
        guard !slice.isEmpty else { throw CalcError.syntax }
        var p = Parser(tokens: slice, ctx: EvalContext(store: ctx.store, depth: ctx.depth + 1))
        return try p.parseStatement().number()
    }

    private func evalSlice(_ slice: [Token], with name: String, equal value: Double) throws -> Double {
        let store = ctx.store
        let old = store.reals[name]
        store.reals[name] = value
        defer { store.reals[name] = old }
        return try evalSlice(slice)
    }

    private mutating func callLazy(_ name: String) throws -> Value {
        let slices = try collectArgSlices()
        func varName(_ i: Int) throws -> String {
            guard i < slices.count, slices[i].count == 1, case .variable(let v) = slices[i][0] else { throw CalcError.argument }
            return v
        }
        switch name {
        case "seq":
            guard slices.count >= 4, slices.count <= 5 else { throw CalcError.argument }
            let v = try varName(1)
            let start = try evalSlice(slices[2]), end = try evalSlice(slices[3])
            let step = slices.count == 5 ? try evalSlice(slices[4]) : 1
            guard step != 0 else { throw CalcError.argument }
            var out: [Double] = []
            var x = start
            while (step > 0 && x <= end + 1e-12) || (step < 0 && x >= end - 1e-12) {
                out.append(try evalSlice(slices[0], with: v, equal: x))
                x += step
                if out.count > 999 { throw CalcError.invalidDim }
            }
            return .list(out)
        case "Σ":
            guard slices.count == 4 else { throw CalcError.argument }
            let v = try varName(1)
            let start = try evalSlice(slices[2]), end = try evalSlice(slices[3])
            var sum = 0.0
            var x = start
            var n = 0
            while x <= end + 1e-12 {
                sum += try evalSlice(slices[0], with: v, equal: x)
                x += 1; n += 1
                if n > 100_000 { throw CalcError.overflow }
            }
            return .num(sum)
        case "fMin", "fMax":
            guard slices.count == 4 else { throw CalcError.argument }
            let v = try varName(1)
            var lo = try evalSlice(slices[2]), hi = try evalSlice(slices[3])
            let sign: Double = name == "fMin" ? 1 : -1
            let phi = (sqrt(5.0) - 1) / 2
            var a = hi - phi * (hi - lo), b = lo + phi * (hi - lo)
            var fa = sign * (try evalSlice(slices[0], with: v, equal: a))
            var fb = sign * (try evalSlice(slices[0], with: v, equal: b))
            for _ in 0..<120 {
                if fa < fb { hi = b; b = a; fb = fa; a = hi - phi * (hi - lo); fa = sign * (try evalSlice(slices[0], with: v, equal: a)) }
                else { lo = a; a = b; fa = fb; b = lo + phi * (hi - lo); fb = sign * (try evalSlice(slices[0], with: v, equal: b)) }
            }
            return .num((lo + hi) / 2)
        case "nDeriv":
            guard slices.count >= 3, slices.count <= 4 else { throw CalcError.argument }
            let v = try varName(1)
            let x = try evalSlice(slices[2])
            let h = slices.count == 4 ? try evalSlice(slices[3]) : 0.001
            let f1 = try evalSlice(slices[0], with: v, equal: x + h)
            let f0 = try evalSlice(slices[0], with: v, equal: x - h)
            return .num((f1 - f0) / (2 * h))
        case "fnInt":
            guard slices.count >= 4, slices.count <= 5 else { throw CalcError.argument }
            let v = try varName(1)
            let lo = try evalSlice(slices[2]), hi = try evalSlice(slices[3])
            let n = 400
            let h = (hi - lo) / Double(n)
            var sum = try evalSlice(slices[0], with: v, equal: lo) + (try evalSlice(slices[0], with: v, equal: hi))
            for i in 1..<n {
                let x = lo + Double(i) * h
                sum += (i % 2 == 0 ? 2 : 4) * (try evalSlice(slices[0], with: v, equal: x))
            }
            return .num(sum * h / 3)
        default:
            throw CalcError.syntax
        }
    }
}

enum Postfix {
    static func apply(_ p: String, _ v: Value, _ ctx: EvalContext) throws -> Value {
        let degrees = ctx.store.degrees
        switch p {
        case "²": return try Value.apply(.mul, v, v)
        case "³": return try Value.apply(.mul, try Value.apply(.mul, v, v), v)
        case "⁻¹":
            if case .matrix(let m) = v { return .matrix(try Matrix.inverse(m)) }
            return try v.mapNumbers { if $0 == 0 { throw CalcError.divideByZero }; return 1 / $0 }
        case "!":
            return try v.mapNumbers { x in
                if x < 0 || x > 69 { throw CalcError.domain }
                if x.rounded() == x { return (1...max(1, Int(x))).reduce(1.0) { $0 * Double($1) } }
                if (x * 2).rounded() != x * 2 { throw CalcError.domain }
                return tgamma(x + 1)
            }
        case "°": return try v.mapNumbers { degrees ? $0 : $0 * .pi / 180 }
        case "ʳ": return try v.mapNumbers { degrees ? $0 * 180 / .pi : $0 }
        case "'": return try v.mapNumbers { degrees ? $0 / 60 : $0 / 60 * .pi / 180 }
        case "ᵀ":
            guard case .matrix(let m) = v else { throw CalcError.dataType }
            return .matrix(Matrix.transpose(m))
        case "▶Frac", "▶n/d◀▶Un/d":
            let x = try v.number()
            return Value.fraction(from: x) ?? .num(x)
        case "▶Dec": return .num(try v.number())
        case "▶F◀▶D":
            if case .fraction = v { return .num(try v.number()) }
            let x = try v.number()
            return Value.fraction(from: x) ?? .num(x)
        case "▶Rect", "▶Polar": return v
        case "▶DMS":
            let x = try v.number()
            let sign = x < 0 ? "⁻" : ""
            let a = abs(x)
            let d = floor(a)
            let mFull = (a - d) * 60
            let m = floor(mFull)
            let s = (mFull - m) * 60
            let secs = (s * 1000).rounded() / 1000
            return .str("\(sign)\(Int(d))°\(Int(m))'\(ResultFormatter.number(secs))\"")
        default:
            throw CalcError.syntax
        }
    }
}

enum Evaluator {
    static func evaluate(_ text: String, ctx: EvalContext) throws -> Value {
        let tokens = try Tokenizer.tokenize(text)
        var parser = Parser(tokens: tokens, ctx: ctx)
        let v = try parser.parseStatement()
        if let d = v.asDouble {
            if !d.isFinite || abs(d) >= 1e100 { throw CalcError.overflow }
        }
        return v
    }

    static func number(_ text: String, ctx: EvalContext) throws -> Double {
        try evaluate(text, ctx: ctx).number()
    }
}

enum Commands {
    static func run(_ name: String, args: [Token], ctx: EvalContext) throws -> Value {
        let store = ctx.store
        func arg(_ i: Int) throws -> Double {
            guard i < args.count else { throw CalcError.argument }
            var p = Parser(tokens: [args[i]], ctx: ctx)
            return try p.parseStatement().number()
        }
        switch name {
        case "ClrHome": store.pendingClrHome = true
        case "ClrDraw": store.drawings = []
        case "ClrTable": break
        case "ClrAllLists": for k in store.lists.keys { store.lists[k] = [] }
        case "ClrList": for t in args { if case .listVar(let n) = t { store.lists[n] = [] } }
        case "PlotsOff": for i in 1...3 { store.options["plot\(i)On"] = 1 }
        case "PlotsOn": for i in 1...3 { store.options["plot\(i)On"] = 0 }
        case "Degree": store.options["angle"] = 1
        case "Radian": store.options["angle"] = 0
        case "Float": store.options["float"] = 0
        case "Fix": store.options["float"] = min(9, max(0, Int(try arg(0)))) + 1
        case "Normal": store.options["notation"] = 0
        case "Sci": store.options["notation"] = 1
        case "Eng": store.options["notation"] = 2
        case "FnOn", "FnOff":
            let on = name == "FnOn"
            let targets = args.compactMap { t -> Int? in if case .yVar(let n) = t { return n }; return nil }
            for n in (targets.isEmpty ? Array(0...9) : targets) { store.yEnabled[n] = on }
        case "AxesOn": store.options["axes"] = 0
        case "AxesOff": store.options["axes"] = 1
        case "GridOff": store.options["grid"] = 0
        case "GridOn", "GridDot": store.options["grid"] = 1
        case "GridLine": store.options["grid"] = 2
        case "CoordOn": store.options["coordOn"] = 0
        case "CoordOff": store.options["coordOn"] = 1
        case "LabelOff": store.options["label"] = 0
        case "LabelOn": store.options["label"] = 1
        case "ExprOn": store.options["expr"] = 0
        case "ExprOff": store.options["expr"] = 1
        case "Connected": store.options["line"] = 0
        case "Dot": store.options["line"] = 1
        case "Sequential": store.options["seq"] = 0
        case "Simul": store.options["seq"] = 1
        case "Real": store.options["complex"] = 0
        case "Full": store.options["screen"] = 0
        case "Horiz": store.options["screen"] = 1
        case "G-T": store.options["screen"] = 2
        case "Clear Entries": store.entries = []
        case "DiagnosticOn": store.options["statdiag"] = 1
        case "DiagnosticOff": store.options["statdiag"] = 0
        case "SetUpEditor": break
        case "ZStandard": Graphing.zoom(.standard, store: store)
        case "ZDecimal": Graphing.zoom(.decimal, store: store)
        case "ZSquare": Graphing.zoom(.square, store: store)
        case "ZTrig": Graphing.zoom(.trig, store: store)
        case "ZInteger": Graphing.zoom(.integer, store: store)
        case "ZoomStat": Graphing.zoom(.stat, store: store)
        case "ZoomFit": Graphing.zoom(.fit, store: store)
        case "ZPrevious": Graphing.zoom(.previous, store: store)
        case "ZoomSto": Graphing.zoom(.sto, store: store)
        case "ZoomRcl": Graphing.zoom(.rcl, store: store)
        case "ZoomIn": Graphing.zoom(.zoomIn, store: store)
        case "ZoomOut": Graphing.zoom(.zoomOut, store: store)
        case "ZQuadrant1": Graphing.zoom(.quadrant1, store: store)
        case "Horizontal":
            store.drawings.append(.horizontal(try arg(0))); store.pendingShowGraph = true
        case "Vertical":
            store.drawings.append(.vertical(try arg(0))); store.pendingShowGraph = true
        case "DrawF":
            let text = args.map { Tokenizer.describe($0) }.joined()
            store.drawings.append(.function(text)); store.pendingShowGraph = true
        default:
            throw CalcError.syntax
        }
        if name.hasPrefix("Z") { store.pendingShowGraph = true }
        return .str("Done")
    }
}

extension Tokenizer {
    /// Best-effort text form of a token (used to re-serialize DrawF arguments).
    static func describe(_ t: Token) -> String {
        switch t {
        case .number(let d): return ResultFormatter.number(d)
        case .string(let s): return "\"\(s)\""
        case .op(let op):
            switch op {
            case .add: return "+"; case .sub: return "−"; case .mul: return "×"; case .div: return "÷"; case .pow: return "^"
            case .nthRoot: return "ˣ√"; case .nCr: return " nCr "; case .nPr: return " nPr "
            case .eq: return "="; case .ne: return "≠"; case .gt: return ">"; case .ge: return "≥"; case .lt: return "<"; case .le: return "≤"
            case .and: return " and "; case .or: return " or "; case .xor: return " xor "
            }
        case .negate: return "⁻"
        case .postfix(let p): return p
        case .lparen: return "("; case .rparen: return ")"; case .lbrace: return "{"; case .rbrace: return "}"
        case .lbracket: return "["; case .rbracket: return "]"; case .comma: return ","; case .store: return "→"
        case .function(let n): return n + "("
        case .nullary(let n): return n
        case .pi: return "π"; case .e: return "e"; case .ans: return "Ans"
        case .variable(let v): return v
        case .listVar(let l): return "L" + subscripts[Int(l.dropFirst()) ?? 1]
        case .matVar(let m): return "[\(m)]"
        case .yVar(let n): return "Y" + subscripts[n]
        case .command(let c): return c
        }
    }
}
