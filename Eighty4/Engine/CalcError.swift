import Foundation

enum CalcError: Error, Equatable {
    case syntax
    case divideByZero
    case domain
    case overflow
    case dimMismatch
    case dataType
    case argument
    case singular
    case invalidDim
    case undefined
    case noSignChange
    case badGuess
    case windowRange

    var message: String {
        switch self {
        case .syntax: return "ERR:SYNTAX"
        case .divideByZero: return "ERR:DIVIDE BY 0"
        case .domain: return "ERR:DOMAIN"
        case .overflow: return "ERR:OVERFLOW"
        case .dimMismatch: return "ERR:DIM MISMATCH"
        case .dataType: return "ERR:DATA TYPE"
        case .argument: return "ERR:ARGUMENT"
        case .singular: return "ERR:SINGULAR MAT"
        case .invalidDim: return "ERR:INVALID DIM"
        case .undefined: return "ERR:UNDEFINED"
        case .noSignChange: return "ERR:NO SIGN CHNG"
        case .badGuess: return "ERR:BAD GUESS"
        case .windowRange: return "ERR:WINDOW RANGE"
        }
    }
}
