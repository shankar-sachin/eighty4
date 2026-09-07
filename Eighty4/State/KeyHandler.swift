import Foundation

extension CalculatorState {
    func press(_ key: KeyID) {
        // Power state.
        if screen == .off {
            if key == .on { screen = .home; modifier = .none }
            return
        }

        // Error screen: any key returns to the home screen with the entry intact (2:Goto).
        if case .error = screen {
            screen = .home
            modifier = .none
            return
        }

        // Modifier keys.
        if key == .second {
            modifier = (modifier == .second) ? .none : .second
            return
        }
        if key == .alpha {
            switch modifier {
            case .second: modifier = .alphaLock
            case .alpha, .alphaLock: modifier = .none
            case .none: modifier = .alpha
            }
            return
        }

        let mod = modifier
        if mod != .alphaLock { modifier = .none }

        if screen == .comingSoon {
            if key == .clear || key == .on || (key == .mode && mod == .second) {
                screen = .home
            }
            return
        }

        if mod == .alpha || mod == .alphaLock {
            if let a = Keymap.spec(key)?.alpha, let ch = alphaCharacter(a) {
                insert(ch)
            }
            return
        }

        if mod == .second {
            handleSecond(key)
        } else {
            handlePrimary(key)
        }
    }

    private func alphaCharacter(_ label: String) -> String? {
        if label == "␣" { return " " }
        if label.count == 1 { return label }
        return nil   // F1–F5, SOLVE etc. have no alpha character
    }

    private func handlePrimary(_ key: KeyID) {
        if Keymap.comingSoonPrimary.contains(key) {
            screen = .comingSoon
            return
        }
        switch key {
        case .zero: insert("0")
        case .one: insert("1")
        case .two: insert("2")
        case .three: insert("3")
        case .four: insert("4")
        case .five: insert("5")
        case .six: insert("6")
        case .seven: insert("7")
        case .eight: insert("8")
        case .nine: insert("9")
        case .dot: insert(".")
        case .negate: insert("⁻")
        case .plus: insert("+")
        case .minus: insert("−")
        case .multiply: insert("×")
        case .divide: insert("÷")
        case .power: insert("^")
        case .square: insert("²")
        case .inverse: insert("⁻¹")
        case .lparen: insert("(")
        case .rparen: insert(")")
        case .comma: insert(",")
        case .xtn: insert("X")
        case .sin: insert("sin(")
        case .cos: insert("cos(")
        case .tan: insert("tan(")
        case .log: insert("log(")
        case .ln: insert("ln(")
        case .enter: evaluate()
        case .clear:
            if entry.isEmpty { history = [] } else { entry = []; cursor = 0 }
        case .del: deleteAtCursor()
        case .left: cursor = max(0, cursor - 1)
        case .right: cursor = min(entry.count, cursor + 1)
        case .up, .down, .on, .second, .alpha:
            break
        default:
            break
        }
    }

    private func handleSecond(_ key: KeyID) {
        if Keymap.comingSoonSecond.contains(key) {
            screen = .comingSoon
            return
        }
        switch key {
        case .sin: insert("sin⁻¹(")
        case .cos: insert("cos⁻¹(")
        case .tan: insert("tan⁻¹(")
        case .log: insert("10^(")
        case .ln: insert("e^(")
        case .square: insert("√(")
        case .power: insert("π")
        case .divide: insert("e")
        case .negate: insert("Ans")
        case .comma: insert("ᴇ")
        case .lparen: insert("{")
        case .rparen: insert("}")
        case .multiply: insert("[")
        case .minus: insert("]")
        case .dot: insert("i")
        case .one: insert("L₁")
        case .two: insert("L₂")
        case .three: insert("L₃")
        case .four: insert("L₄")
        case .five: insert("L₅")
        case .six: insert("L₆")
        case .seven: insert("u")
        case .eight: insert("v")
        case .nine: insert("w")
        case .enter:
            entry = Array(lastEntry)
            cursor = entry.count
        case .on: screen = .off
        case .mode: break          // QUIT: already on the home screen
        case .del: insertMode.toggle()
        case .up, .down, .left, .right:
            handlePrimary(key)
        case .clear:
            handlePrimary(key)
        default:
            handlePrimary(key)
        }
    }
}
