import Foundation

/// MATH 0:Solver (TI-84 Plus CE) / Numeric Solver (TI-84 Evo) — numeric root finding for one variable.
///
/// The equation may be written either as a bare expression (`X²−4`, solved against 0, as the CE's
/// `eqn:0=` prompt asks) or as a full equation with an `=` (`2ˣ=X²`, as the Evo's Numeric Solver takes).
/// Everything downstream works on the *residual*: left − right.
enum Solver {
    static let defaultBound = 1e99

    /// `left=right` → `(left)−(right)`; an expression with no top-level `=` is returned unchanged.
    /// Only a top-level `=` counts, so `piecewise(1,X=2,3)` and list/matrix contents are left alone.
    static func residual(_ eqn: String) -> String {
        let chars = Array(eqn)
        var depth = 0
        for (i, c) in chars.enumerated() {
            if c == "(" || c == "{" || c == "[" || MathPrint.isOpen(c) { depth += 1 }
            else if c == ")" || c == "}" || c == "]" || MathPrint.isClose(c) { depth -= 1 }
            else if c == "=", depth == 0 {
                let left = String(chars[..<i]), right = String(chars[(i + 1)...])
                guard !left.isEmpty, !right.isEmpty else { return eqn }
                return "(" + left + ")−(" + right + ")"
            }
        }
        return eqn
    }

    /// True when the equation was written with an `=` of its own.
    static func isEquation(_ eqn: String) -> Bool { residual(eqn) != eqn }

    /// How the equation is echoed above the variable list.
    static func title(_ eqn: String) -> String { isEquation(eqn) ? eqn : eqn + "=0" }

    /// Single-letter variables (and θ) in the equation, in order of first appearance.
    static func variables(in eqn: String) -> [String] {
        guard let tokens = try? Tokenizer.tokenize(residual(eqn)) else { return [] }
        var out: [String] = []
        for t in tokens {
            if case .variable(let v) = t, v.count == 1, !Tokenizer.statVars.contains(v), !["a", "b", "c", "d", "r", "n", "u", "v", "w"].contains(v), !out.contains(v) {
                out.append(v)
            }
        }
        return out
    }

    /// left − rt for the current variable values, or nil when the equation cannot be evaluated.
    static func residualValue(_ eqn: String, store: VariableStore) -> Double? {
        guard let v = try? Evaluator.number(residual(eqn), ctx: EvalContext(store: store)), v.isFinite else { return nil }
        return v
    }

    /// Solves the equation for `name` starting at `guess`, staying inside [lo, hi].
    /// Newton first (fast, and the only thing that finds a root the guess already sits on), then a
    /// bracketing scan outward from the guess followed by bisection. A candidate is only returned
    /// when the residual there really is zero, so a stalled Newton can't report a non-root.
    static func solve(_ eqn: String, for name: String, guess: Double, lo: Double, hi: Double, store: VariableStore) throws -> Double {
        let expr = residual(eqn)
        let low = min(lo, hi), high = max(lo, hi)
        let ctx = EvalContext(store: store)

        func f(_ x: Double) throws -> Double {
            let old = store.overrides[name]
            store.overrides[name] = x
            defer { store.overrides[name] = old }
            return try Evaluator.evaluate(expr, ctx: ctx).number()
        }
        /// Finite value or nil (the equation may be undefined at x, e.g. ln of a negative).
        func fv(_ x: Double) -> Double? {
            guard let v = try? f(x), v.isFinite else { return nil }
            return v
        }
        // A syntax or type error in the equation must surface rather than read as "no root".
        let start = min(high, max(low, guess))
        let f0 = try f(start)
        if f0 == 0 { return start }
        // Judge a candidate against the size of the residual we started from, not against x: a
        // tolerance that grew with x would accept any large number for an equation like 1÷X=0.
        let scale = max(1, abs(f0))
        func isRoot(_ x: Double, _ fx: Double) -> Bool { abs(fx) <= 1e-10 * scale }

        // 1. Newton with a numeric derivative.
        var x = start
        for _ in 0..<80 {
            guard let fx = fv(x) else { break }
            if fx == 0 { return x }
            let h = max(1e-7, abs(x) * 1e-7)
            guard let fa = fv(x + h), let fb = fv(x - h) else { break }
            let d = (fa - fb) / (2 * h)
            guard d.isFinite, d != 0 else { break }
            var next = x - fx / d
            guard next.isFinite else { break }
            next = min(high, max(low, next))
            let settled = abs(next - x) <= 1e-13 * max(1, abs(x))
            x = next
            if settled { break }
        }
        if let fx = fv(x), isRoot(x, fx) { return x }

        // 2. Walk outward from the guess in growing steps until the residual changes sign.
        if let (a, b) = bracket(around: start, low: low, high: high, fv) {
            if a == b { return a }
            let root = Stats.bisect({ fv($0) ?? 0 }, a, b)
            guard let fr = fv(root) else { throw CalcError.noSignChange }   // a pole, not a root
            // A sign change across a pole is not a root: there the residual blows up instead of vanishing.
            let edge = max(abs(fv(a) ?? 0), abs(fv(b) ?? 0))
            if isRoot(root, fr) || abs(fr) <= 1e-6 * edge { return root }
        }
        throw CalcError.noSignChange
    }

    /// A pair (a, b) with a sign change between them, or (r, r) when a sample lands exactly on a root.
    private static func bracket(around start: Double, low: Double, high: Double, _ fv: (Double) -> Double?) -> (Double, Double)? {
        var leftEdge = start, rightEdge = start
        var fLeft = fv(start), fRight = fLeft
        var step = max(1e-4, abs(start) * 1e-4)
        for _ in 0..<200 {
            if rightEdge < high {
                let r = min(high, rightEdge + step)
                if let v = fv(r) {
                    if v == 0 { return (r, r) }
                    if let p = fRight, (p < 0) != (v < 0) { return (rightEdge, r) }
                    fRight = v
                } else {
                    fRight = nil
                }
                rightEdge = r
            }
            if leftEdge > low {
                let l = max(low, leftEdge - step)
                if let v = fv(l) {
                    if v == 0 { return (l, l) }
                    if let p = fLeft, (p < 0) != (v < 0) { return (l, leftEdge) }
                    fLeft = v
                } else {
                    fLeft = nil
                }
                leftEdge = l
            }
            if leftEdge <= low && rightEdge >= high { break }
            step *= 1.35
        }
        return nil
    }
}
