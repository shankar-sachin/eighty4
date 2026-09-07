import Foundation

enum CalcError: Error, Equatable {
    case syntax
    case divideByZero
    case domain
    case overflow

    var message: String {
        switch self {
        case .syntax: return "ERR:SYNTAX"
        case .divideByZero: return "ERR:DIVIDE BY 0"
        case .domain: return "ERR:DOMAIN"
        case .overflow: return "ERR:OVERFLOW"
        }
    }
}
