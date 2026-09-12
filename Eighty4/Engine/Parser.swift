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
            else if case .complex(let re, let im) = v {
                store.complexes[name] = [re, im]
                store.reals.removeValue(forKey: name)
            } else {
                store.reals[name] = try v.number()
                store.complexes.removeValue(forKey: name)
            }
        case .listVar(let name):
            if case .clist(let l) = v {
                store.complexLists[name] = l.map { [$0.re, $0.im] }
                store.lists[name] = []
            } else {
                store.lists[name] = try v.listValue()
                store.complexLists.removeValue(forKey: name)
            }
        case .matVar(let name):
            try store.setMatrix(name, v)
        case .yVar(let n):
            guard case .str(let s) = v else { throw CalcError.dataType }
            store.yFuncs[n] = s
        case .namedFunc(let key):
            guard case .str(let s) = v else { throw CalcError.dataType }
            store.setFuncText(key, s)
        case .strVar(let n):
            guard case .str(let s) = v else { throw CalcError.dataType }
            store.strings[n] = s
        default:
            throw CalcError.syntax
        }
    }

    // MARK: - Precedence chain

    /// Conversions (▶Frac ▶Dec ▶DMS ▶F◀▶D ▶Rect ▶Polar ▶n/d◀▶Un/d) apply to the whole expression, as on the CE.
    private mutating func expr() throws -> Value {
        var v = try logicOr()
        while let t = peek, case .postfix(let p) = t, p.hasPrefix("▶") {
            advance()
            v = try Postfix.apply(p, v, ctx)
        }
        return v
    }

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
        // Mixed number a_b/c (FRAC Un/d template).
        if pos + 4 < tokens.count, case .number(let a) = tokens[pos], tokens[pos + 1] == .op(.mixed),
           case .number(let b) = tokens[pos + 2], tokens[pos + 3] == .op(.div), case .number(let c) = tokens[pos + 4],
           a.rounded() == a, b.rounded() == b, c.rounded() == c, c > 0 {
            pos += 5
            return .fraction(Int(a) * Int(c) + Int(b), Int(c))
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
        while let t = peek, case .postfix(let p) = t, !p.hasPrefix("▶") {
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
        case .imaginary: advance(); return .complex(0, 1)
        case .nullary(let name): advance(); return try Functions.call(name, [], ctx)
        case .variable(let name):
            advance()
            if ["u", "v", "w"].contains(name), peek == .lparen {
                advance()
                let n = try expr().number()
                try closeParen()
                return .num(try Sequences.value(name, n: Int(n.rounded()), store: store, depth: ctx.depth))
            }
            if let c = store.complexes[name], c.count == 2, store.overrides[name] == nil { return Value.cx(c[0], c[1]) }
            return .num(store.lookupReal(name))
        case .listVar(let name):
            advance()
            if let c = store.complexLists[name] { return .clist(c.map { Cx(re: $0.first ?? 0, im: $0.count > 1 ? $0[1] : 0) }) }
            guard let l = store.lists[name] else { throw CalcError.undefined }
            return .list(l)
        case .matVar(let name):
            advance()
            guard let m = store.matrixValue(name) else { throw CalcError.undefined }
            return m
        case .yVar(let n):
            advance()
            return try evalFunc("Y\(n)")
        case .namedFunc(let key):
            advance()
            return try evalFunc(key)
        case .strVar(let n):
            advance()
            guard let s = store.strings[n] else { throw CalcError.undefined }
            return .str(s)
        case .lparen:
            advance()
            let v = try expr()
            try closeParen()
            return v
        case .lbrace:
            advance()
            var items: [(Double, Double)] = []
            if peek == .rbrace { advance(); return .list([]) }
            while true {
                guard let z = try expr().asComplex else { throw CalcError.dataType }
                items.append(z)
                if peek == .comma { advance(); continue }
                break
            }
            if peek == .rbrace { advance() } else if pos != tokens.count { throw CalcError.syntax }
            return Value.fromComplexElements(items)
        case .lbracket:
            advance()
            var rows: [[Cx]] = []
            while peek == .lbracket {
                advance()
                var row: [Cx] = []
                while true {
                    guard let z = try expr().asComplex else { throw CalcError.dataType }
                    row.append(Cx(re: z.0, im: z.1))
                    if peek == .comma { advance(); continue }
                    break
                }
                guard peek == .rbracket else { throw CalcError.syntax }
                advance()
                rows.append(row)
            }
            if peek == .rbracket { advance() } else if pos != tokens.count { throw CalcError.syntax }
            guard !rows.isEmpty, Set(rows.map(\.count)).count == 1 else { throw CalcError.invalidDim }
            return Value.fromComplexRows(rows)
        case .fracOpen:
            return try fractionTemplate()
        case .mixedOpen:
            // Un/d template: whole number slot, then the fraction template.
            advance()
            var wholeTokens: [Token] = []
            while let t = peek, t != .fracOpen { wholeTokens.append(t); advance() }
            guard peek == .fracOpen else { throw CalcError.syntax }
            let whole = try evalSliceValue(wholeTokens)
            let frac = try fractionTemplate()
            guard let w = whole.asDouble else { throw CalcError.dataType }
            let sign: Double = w < 0 ? -1 : 1
            if w.rounded() == w, case .fraction(let n, let d) = frac { return .fraction(Int(w) * d + Int(sign) * n, d) }
            return try Value.apply(.add, whole, try Value.apply(.mul, .num(sign), frac))
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

    /// ⌈n⌉/⌊d⌋: integer numerator and denominator give an exact fraction, anything else divides.
    private mutating func fractionTemplate() throws -> Value {
        guard peek == .fracOpen else { throw CalcError.syntax }
        advance()
        let n = try expr()
        guard peek == .fracSep else { throw CalcError.syntax }
        advance()
        let d = try expr()
        if peek == .fracClose { advance() } else if pos != tokens.count { throw CalcError.syntax }
        // Integer (or already-fractional) slots keep the result exact: ⌈⌈1⌉/⌊2⌋⌉/⌊3⌋ = 1/6.
        func rational(_ v: Value) -> (Int, Int)? {
            if case .fraction(let a, let b) = v { return (a, b) }
            if let a = v.asDouble, a.rounded() == a, abs(a) < 1e12 { return (Int(a), 1) }
            return nil
        }
        if let (a, b) = rational(n), let (c, e) = rational(d) {
            guard c != 0 else { throw CalcError.divideByZero }
            var num = a * e, den = b * c
            if den < 0 { num = -num; den = -den }
            let g = max(1, Stats.gcd(abs(num), den))
            return .fraction(num / g, den / g)
        }
        return try Value.apply(.div, n, d)
    }

    private func evalFunc(_ key: String) throws -> Value {
        guard ctx.depth < 8 else { throw CalcError.undefined }
        guard let text = ctx.store.funcText(key), !text.isEmpty else { throw CalcError.undefined }
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

    private func evalSliceValue(_ slice: [Token]) throws -> Value {
        guard !slice.isEmpty else { throw CalcError.syntax }
        var p = Parser(tokens: slice, ctx: EvalContext(store: ctx.store, depth: ctx.depth + 1))
        return try p.parseStatement()
    }

    private func evalSlice(_ slice: [Token]) throws -> Double {
        try evalSliceValue(slice).number()
    }

    private func evalSlice(_ slice: [Token], with name: String, equal value: Double) throws -> Double {
        let store = ctx.store
        let old = store.reals[name]
        store.reals[name] = value
        defer { store.reals[name] = old }
        return try evalSlice(slice)
    }

    private func sliceText(_ slice: [Token]) -> String {
        slice.map { Tokenizer.describe($0) }.joined()
    }

    private mutating func callLazy(_ name: String) throws -> Value {
        let slices = try collectArgSlices()
        let store = ctx.store
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
        case "Fill":
            // Fill(value, Ln) or Fill(value, [A])
            guard slices.count == 2, slices[1].count == 1 else { throw CalcError.argument }
            guard let value = try evalSliceValue(slices[0]).asComplex else { throw CalcError.dataType }
            switch slices[1][0] {
            case .listVar(let l):
                let n = store.complexLists[l]?.count ?? store.lists[l]?.count ?? 0
                try storeValue(Value.fromComplexElements(Array(repeating: value, count: n)), into: .listVar(l))
            case .matVar(let m):
                guard let mm = store.matrices[m] else { throw CalcError.undefined }
                store.setMatrix(m, mm.map { $0.map { _ in Cx(re: value.0, im: value.1) } })
            default: throw CalcError.argument
            }
            return .str("Done")
        case "Matr▶list":
            // Matr▶list([A], L1, L2…) or Matr▶list([A], col, L1)
            guard slices.count >= 2, slices[0].count == 1, case .matVar(let m) = slices[0][0], let mm = store.matrixRows(m) else { throw CalcError.argument }
            let cols = Matrix.transpose(mm).map { Value.fromComplexElements($0.map { ($0.re, $0.im) }) }
            if slices.count == 3, slices[2].count == 1, case .listVar(let l) = slices[2][0], slices[1].count == 1, case .number(let c) = slices[1][0] {
                let ci = Int(c) - 1
                guard ci >= 0, ci < cols.count else { throw CalcError.invalidDim }
                try storeValue(cols[ci], into: .listVar(l))
                return .str("Done")
            }
            for (i, s) in slices.dropFirst().enumerated() {
                guard s.count == 1, case .listVar(let l) = s[0] else { throw CalcError.argument }
                guard i < cols.count else { break }
                try storeValue(cols[i], into: .listVar(l))
            }
            return .str("Done")
        case "List▶matr":
            // List▶matr(L1, L2, …, [A])
            guard slices.count >= 2, slices.last!.count == 1, case .matVar(let m) = slices.last![0] else { throw CalcError.argument }
            var cols: [[Cx]] = []
            for s in slices.dropLast() {
                guard let xs = try evalSliceValue(s).asComplexElements else { throw CalcError.dataType }
                cols.append(xs.map { Cx(re: $0.0, im: $0.1) })
            }
            let rows = cols.map(\.count).max() ?? 0
            guard rows > 0 else { throw CalcError.invalidDim }
            store.setMatrix(m, (0..<rows).map { r in cols.map { r < $0.count ? $0[r] : .zero } })
            return .str("Done")
        case "piecewise":
            // piecewise(expr1, cond1, expr2, cond2, …[, else]) — conditions are evaluated in order, lazily.
            guard !slices.isEmpty else { throw CalcError.argument }
            var i = 0
            while i < slices.count {
                if i + 1 == slices.count { return try evalSliceValue(slices[i]) }
                if try evalSlice(slices[i + 1]) != 0 { return try evalSliceValue(slices[i]) }
                i += 2
            }
            throw CalcError.domain
        case "Tangent":
            guard slices.count == 2 else { throw CalcError.argument }
            let x = try evalSlice(slices[1])
            store.drawings.append(.tangent(sliceText(slices[0]), x))
            store.pendingShowGraph = true
            return .str("Done")
        case "Shade":
            guard slices.count >= 2 else { throw CalcError.argument }
            let xl = slices.count > 2 ? try evalSlice(slices[2]) : nil
            let xr = slices.count > 3 ? try evalSlice(slices[3]) : nil
            store.drawings.append(.shade(sliceText(slices[0]), sliceText(slices[1]), xl, xr))
            store.pendingShowGraph = true
            return .str("Done")
        case "expr", "eval":
            guard slices.count == 1 else { throw CalcError.argument }
            guard case .str(let s) = try evalSliceValue(slices[0]) else { throw CalcError.dataType }
            guard ctx.depth < 8 else { throw CalcError.undefined }
            let v = try Evaluator.evaluate(s, ctx: EvalContext(store: store, depth: ctx.depth + 1))
            return name == "eval" ? .str(ResultFormatter.format(v, store: store)) : v
        default:
            throw CalcError.syntax
        }
    }
}

enum Postfix {
    static func apply(_ p: String, _ v: Value, _ ctx: EvalContext) throws -> Value {
        let unit = ctx.store.radiansPerUnit   // radians per unit of the MODE angle (RADIAN / DEGREE / GRADIAN)
        switch p {
        case "²": return try Value.apply(.mul, v, v)
        case "³": return try Value.apply(.mul, try Value.apply(.mul, v, v), v)
        case "⁻¹":
            if v.isComplex { return try Value.apply(.div, .num(1), v) }
            if case .matrix(let m) = v { return .matrix(try Matrix.inverse(m)) }
            if case .cmatrix(let m) = v { return Value.fromComplexRows(try Matrix.inverse(m)) }
            return try v.mapNumbers { if $0 == 0 { throw CalcError.divideByZero }; return 1 / $0 }
        case "!":
            return try v.mapNumbers { x in
                if x < 0 || x > 69 { throw CalcError.domain }
                if x.rounded() == x { return (1...max(1, Int(x))).reduce(1.0) { $0 * Double($1) } }
                if (x * 2).rounded() != x * 2 { throw CalcError.domain }
                return tgamma(x + 1)
            }
        case "%": return try v.mapNumbers { $0 / 100 }
        case "°": return try v.mapNumbers { $0 * (.pi / 180) / unit }
        case "ʳ": return try v.mapNumbers { $0 / unit }
        case "'": return try v.mapNumbers { $0 / 60 * (.pi / 180) / unit }
        case "ᵀ":
            if case .cmatrix(let m) = v { return .cmatrix(Matrix.transpose(m)) }
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
        case "▶Rect": ctx.store.pendingComplexForm = 1; return v
        case "▶Polar": ctx.store.pendingComplexForm = 2; return v
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
        Value.complexResults = ctx.store.options["complex", default: 0] > 0
        if ctx.depth == 0 { ctx.store.pendingComplexForm = nil }
        let tokens = try Tokenizer.tokenize(text)
        var parser = Parser(tokens: tokens, ctx: ctx)
        let v = try parser.parseStatement()
        if let d = v.asDouble {
            if !d.isFinite || abs(d) >= 1e100 { throw CalcError.overflow }
        }
        if case .complex(let re, let im) = v, !re.isFinite || !im.isFinite || hypot(re, im) >= 1e100 { throw CalcError.overflow }
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
        /// Picture / GDB number from either "Pic3" or a plain number.
        func slot() throws -> Int {
            guard let t = args.first else { throw CalcError.argument }
            switch t {
            case .picVar(let n), .gdbVar(let n): return n
            default:
                let n = Int(try arg(0))
                guard (0...9).contains(n) else { throw CalcError.argument }
                return n
            }
        }
        switch name {
        case "ClrHome": store.pendingClrHome = true
        case "ClrDraw": store.drawings = []
        case "ClrTable": break
        case "ClrAllLists": for k in store.lists.keys { store.lists[k] = [] }; store.complexLists = [:]
        case "ClrList": for t in args { if case .listVar(let n) = t { store.lists[n] = []; store.complexLists.removeValue(forKey: n) } }
        case "PlotsOff": for i in 1...3 { store.options["plot\(i)On"] = 1 }
        case "PlotsOn": for i in 1...3 { store.options["plot\(i)On"] = 0 }
        case "Degree": store.options["angle"] = 1
        case "Radian": store.options["angle"] = 0
        case "Float": store.options["float"] = 0
        case "Fix": store.options["float"] = min(9, max(0, Int(try arg(0)))) + 1
        case "Normal": store.options["notation"] = 0
        case "Sci": store.options["notation"] = 1
        case "Eng": store.options["notation"] = 2
        case "Func": store.options["graph"] = 0
        case "Param": store.options["graph"] = 1
        case "Polar": store.options["graph"] = 2
        case "Seq": store.options["graph"] = 3
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
        case "a+bi": store.options["complex"] = 1
        case "re^θi": store.options["complex"] = 2
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
        case "ZFrac1/2": Graphing.zoom(.frac(2), store: store)
        case "ZFrac1/3": Graphing.zoom(.frac(3), store: store)
        case "ZFrac1/4": Graphing.zoom(.frac(4), store: store)
        case "Horizontal":
            store.drawings.append(.horizontal(try arg(0))); store.pendingShowGraph = true
        case "Vertical":
            store.drawings.append(.vertical(try arg(0))); store.pendingShowGraph = true
        case "DrawF":
            let text = args.map { Tokenizer.describe($0) }.joined()
            store.drawings.append(.function(text)); store.pendingShowGraph = true
        case "DrawInv":
            let text = args.map { Tokenizer.describe($0) }.joined()
            store.drawings.append(.inverse(text)); store.pendingShowGraph = true
        case "StorePic": store.pics[try slot()] = store.drawings
        case "RecallPic":
            guard let p = store.pics[try slot()] else { throw CalcError.undefined }
            store.drawings += p.filter { !store.drawings.contains($0) }
            store.pendingShowGraph = true
        case "StoreGDB": store.gdbs[try slot()] = store.graphDatabase()
        case "RecallGDB":
            guard let g = store.gdbs[try slot()] else { throw CalcError.undefined }
            store.recall(g)
        case "BackgroundOn":
            let n = Int(try arg(0))
            guard (10...24).contains(n) else { throw CalcError.argument }
            store.options["background"] = n
        case "BackgroundOff": store.options["background"] = 0
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
            case .and: return " and "; case .or: return " or "; case .xor: return " xor "; case .mixed: return "_"
            }
        case .negate: return "⁻"
        case .postfix(let p): return p
        case .lparen: return "("; case .rparen: return ")"; case .lbrace: return "{"; case .rbrace: return "}"
        case .lbracket: return "["; case .rbracket: return "]"; case .comma: return ","; case .store: return "→"
        case .function(let n): return n + "("
        case .nullary(let n): return n
        case .pi: return "π"; case .e: return "e"; case .ans: return "Ans"; case .imaginary: return "i"
        case .variable(let v): return v
        case .listVar(let l): return "L" + subscripts[Int(l.dropFirst()) ?? 1]
        case .matVar(let m): return "[\(m)]"
        case .yVar(let n): return "Y" + subscripts[n]
        case .namedFunc(let k): return namedFuncLabel(k)
        case .strVar(let n): return "Str\(n)"
        case .picVar(let n): return "Pic\(n)"
        case .gdbVar(let n): return "GDB\(n)"
        case .prgm(let p): return "prgm" + p
        case .command(let c): return c
        case .fracOpen: return "("; case .fracSep: return ")/("; case .fracClose: return ")"; case .mixedOpen: return ""
        }
    }
}
