import Foundation

/// MATH 0:Solver — numeric root finding of eqn = 0 for one variable.
enum Solver {
    /// Single-letter variables (and θ) in the equation, in order of first appearance.
    static func variables(in eqn: String) -> [String] {
        guard let tokens = try? Tokenizer.tokenize(eqn) else { return [] }
        var out: [String] = []
        for t in tokens {
            if case .variable(let v) = t, v.count == 1, !Tokenizer.statVars.contains(v), !["a", "b", "c", "d", "r", "n", "u", "v", "w"].contains(v), !out.contains(v) {
                out.append(v)
            }
        }
        return out
    }

    /// Solves eqn = 0 for `name` starting at `guess` within [lo, hi]. Returns the root.
    static func solve(_ eqn: String, for name: String, guess: Double, lo: Double, hi: Double, store: VariableStore) throws -> Double {
        let ctx = EvalContext(store: store)
        func f(_ x: Double) throws -> Double {
            let old = store.overrides[name]
            store.overrides[name] = x
            defer { store.overrides[name] = old }
            let v = try Evaluator.evaluate(eqn, ctx: ctx)
            return try v.number()
        }
        // Newton with numeric derivative from the guess.
        var x = min(hi, max(lo, guess))
        for _ in 0..<60 {
            let fx = try f(x)
            if abs(fx) < 1e-12 { return x }
            let h = max(1e-6, abs(x) * 1e-6)
            let d = (try f(x + h) - (try f(x - h))) / (2 * h)
            guard d != 0, d.isFinite else { break }
            let next = x - fx / d
            guard next.isFinite else { break }
            if abs(next - x) < 1e-12 * max(1, abs(x)) { return min(hi, max(lo, next)) }
            x = min(hi, max(lo, next))
        }
        if let fx = try? f(x), abs(fx) < 1e-9 { return x }
        // Fall back to scanning for a sign change around the guess.
        let span = max(1, abs(guess)) * 10
        let a = max(lo, guess - span), b = min(hi, guess + span)
        let steps = 400
        var prev = a, fprev = try f(a)
        for i in 1...steps {
            let cur = a + (b - a) * Double(i) / Double(steps)
            guard let fc = try? f(cur) else { prev = cur; continue }
            if fprev == 0 { return prev }
            if (fprev < 0) != (fc < 0) {
                return Stats.bisect({ (try? f($0)) ?? 0 }, prev, cur)
            }
            prev = cur; fprev = fc
        }
        throw CalcError.noSignChange
    }
}
