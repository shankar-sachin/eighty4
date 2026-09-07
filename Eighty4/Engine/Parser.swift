import Foundation

/// Recursive-descent evaluator with TI-84 precedence:
/// expr := term (('+'|'−') term)*
/// term := unary (('×'|'÷'|implicit) unary)*
/// unary := '⁻' unary | power
/// power := postfix ('^' unary)?          (right associative; ⁻2² = ⁻4)
/// postfix := primary ('²' | '⁻¹')*
/// primary := number | π | e | Ans | var | '(' expr ')' | fn '(' expr ')'
struct Parser {
    private let tokens: [Token]
    private var pos = 0
    private let ans: Double

    init(tokens: [Token], ans: Double) {
        self.tokens = tokens
        self.ans = ans
    }

    private var peek: Token? { pos < tokens.count ? tokens[pos] : nil }
    private mutating func advance() { pos += 1 }

    mutating func parseAll() throws -> Double {
        if tokens.isEmpty { throw CalcError.syntax }
        let v = try expr()
        if pos != tokens.count { throw CalcError.syntax }
        return v
    }

    private mutating func expr() throws -> Double {
        var v = try term()
        while let t = peek {
            if t == .plus { advance(); v += try term() }
            else if t == .minus { advance(); v -= try term() }
            else { break }
        }
        return v
    }

    private mutating func term() throws -> Double {
        var v = try unary()
        while let t = peek {
            if t == .times {
                advance(); v *= try unary()
            } else if t == .divide {
                advance()
                let d = try unary()
                if d == 0 { throw CalcError.divideByZero }
                v /= d
            } else if t.startsPrimary {
                v *= try unary()   // implicit multiplication: 2π, 3(4), (2)(3)
            } else {
                break
            }
        }
        return v
    }

    private mutating func unary() throws -> Double {
        if peek == .negate {
            advance()
            return -(try unary())
        }
        return try power()
    }

    private mutating func power() throws -> Double {
        let base = try postfix()
        if peek == .power {
            advance()
            let exponent = try unary()
            let r = pow(base, exponent)
            if r.isNaN { throw CalcError.domain }
            return r
        }
        return base
    }

    private mutating func postfix() throws -> Double {
        var v = try primary()
        while let t = peek {
            if t == .square { advance(); v *= v }
            else if t == .inverse {
                advance()
                if v == 0 { throw CalcError.divideByZero }
                v = 1 / v
            } else { break }
        }
        return v
    }

    /// TI allows a missing ')' at the very end of the entry.
    private mutating func closeParen() throws {
        if peek == .rparen { advance(); return }
        if pos == tokens.count { return }
        throw CalcError.syntax
    }

    private mutating func primary() throws -> Double {
        guard let t = peek else { throw CalcError.syntax }
        switch t {
        case .number(let v): advance(); return v
        case .pi: advance(); return Double.pi
        case .e: advance(); return M_E
        case .ans: advance(); return ans
        case .variable: advance(); return 0   // undefined variables are 0 on the TI
        case .lparen:
            advance()
            let v = try expr()
            try closeParen()
            return v
        case .function(let name):
            advance()
            guard peek == .lparen else { throw CalcError.syntax }
            advance()
            let a = try expr()
            try closeParen()
            return try apply(name, a)
        default:
            throw CalcError.syntax
        }
    }

    private func apply(_ name: String, _ a: Double) throws -> Double {
        switch name {
        case "sin": return sin(a)
        case "cos": return cos(a)
        case "tan": return tan(a)
        case "asin": if abs(a) > 1 { throw CalcError.domain }; return asin(a)
        case "acos": if abs(a) > 1 { throw CalcError.domain }; return acos(a)
        case "atan": return atan(a)
        case "log": if a <= 0 { throw CalcError.domain }; return log10(a)
        case "ln": if a <= 0 { throw CalcError.domain }; return Foundation.log(a)
        case "sqrt": if a < 0 { throw CalcError.domain }; return a.squareRoot()
        case "abs": return abs(a)
        default: throw CalcError.syntax
        }
    }
}

enum Evaluator {
    static func evaluate(_ text: String, ans: Double) throws -> Double {
        let tokens = try Tokenizer.tokenize(text)
        var parser = Parser(tokens: tokens, ans: ans)
        let v = try parser.parseAll()
        if !v.isFinite { throw CalcError.overflow }
        if abs(v) >= 1e100 { throw CalcError.overflow }
        return v
    }
}
