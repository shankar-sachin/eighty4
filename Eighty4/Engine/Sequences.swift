import Foundation

/// SEQ-mode sequences u(n), v(n), w(n): explicit or recursive, evaluated iteratively from nMin
/// with a cache so u(n-1)/u(n-2) references stay cheap.
enum Sequences {
    static let names = ["u", "v", "w"]

    private static func cacheKey(_ store: VariableStore) -> String {
        names.map { "\(store.funcs[$0] ?? "")|\(store.funcs["\($0)(nMin)"] ?? "")" }.joined(separator: "‖")
            + "‖\(store.numbers["nMin"] ?? 1)"
    }

    static func value(_ name: String, n: Int, store: VariableStore, depth: Int) throws -> Double {
        guard depth < 12 else { throw CalcError.undefined }
        let key = cacheKey(store)
        if key != store.seqCacheKey { store.seqCache = [:]; store.seqCacheKey = key }
        let nMin = Int((store.numbers["nMin"] ?? 1).rounded())
        guard n >= nMin else { throw CalcError.domain }
        guard n - nMin <= 5000 else { throw CalcError.overflow }
        if let c = store.seqCache[name]?[n] { return c }
        guard let text = store.funcs[name], !text.isEmpty else { throw CalcError.undefined }

        // Initial values: u(nMin) may be a number or a list {u(nMin), u(nMin+1)}.
        if store.seqCache[name] == nil, let initText = store.funcs["\(name)(nMin)"], !initText.isEmpty {
            let v = try Evaluator.evaluate(initText, ctx: EvalContext(store: store, depth: depth + 1))
            var cache: [Int: Double] = [:]
            switch v {
            case .list(let l): for (i, x) in l.enumerated() { cache[nMin + i] = x }
            default: cache[nMin] = try v.number()
            }
            store.seqCache[name] = cache
            if let c = cache[n] { return c }
        }

        var start = nMin
        if let cached = store.seqCache[name], let maxN = cached.keys.max(), maxN < n { start = maxN + 1 }
        for k in start...n {
            if let c = store.seqCache[name]?[k] { _ = c; continue }
            let old = store.overrides["n"]
            store.overrides["n"] = Double(k)
            defer { store.overrides["n"] = old }
            let v = try Evaluator.number(text, ctx: EvalContext(store: store, depth: depth + 1))
            store.seqCache[name, default: [:]][k] = v
        }
        guard let out = store.seqCache[name]?[n] else { throw CalcError.undefined }
        return out
    }
}
