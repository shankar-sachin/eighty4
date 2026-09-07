import Foundation

/// A physical-keyboard event reduced to what the calculator understands.
enum HardwareKey: Equatable {
    case char(Character)
    case enter, backspace, forwardDelete, escape
    case up, down, left, right
    case function(Int)          // F1…F5 → y= window zoom trace graph
}

extension CalculatorState {
    /// Sends a hardware-keyboard key through the same path as tapping the on-screen keypad.
    /// Returns false when the key means nothing to the calculator.
    @discardableResult
    func pressHardware(_ k: HardwareKey) -> Bool {
        defer {
            if case .char(let c) = k, c.isASCII, c.isLetter { hardwareWord.append(c.lowercased()) }
            else { hardwareWord = "" }
        }
        if case .char("(") = k, replaceTypedWordWithFunction() { return true }
        switch k {
        case .enter: press(.enter)
        case .escape: press(.clear)
        case .forwardDelete: press(.del)
        case .backspace:
            // Backspace removes the token before the cursor; DEL removes the one under it.
            if entryHasCursor, cursor > 0, cursor < entry.count { press(.left) }
            press(.del)
        case .up: press(.up)
        case .down: press(.down)
        case .left: press(.left)
        case .right: press(.right)
        case .function(let n):
            let row: [KeyID] = [.yEquals, .window, .zoom, .trace, .graph]
            guard (1...row.count).contains(n) else { return false }
            press(row[n - 1])
        case .char(let c):
            if let token = Self.directTokens[c] { return insertToken(token) }
            guard let (key, mod) = Self.hardwareMap(c) else { return false }
            switch mod {
            case .second: modifier = .second
            case .alpha: if modifier != .alphaLock { modifier = .alpha }
            case .none, .alphaLock: break     // plain characters honour whatever modifier is lit
            }
            press(key)
        }
        return true
    }

    /// True when the current screen edits `entry` with a movable cursor.
    private var entryHasCursor: Bool {
        if let r = runner {
            if case .input = r.wait { return true }
            return false
        }
        switch screen {
        case .home, .yEquals, .programEditor: return true
        case .solver: return solverStage == 0
        default: return false
        }
    }

    /// Typing "sin" then "(" on a keyboard inserts the letters S, I, N (variables); when the "(" arrives,
    /// swap a typed word that names a function for that function's token. Returns true if it did.
    private func replaceTypedWordWithFunction() -> Bool {
        let word = hardwareWord
        guard word.count >= 2, entryHasCursor, cursor >= word.count else { return false }
        let typed = String(entry[(cursor - word.count)..<cursor])
        guard typed.lowercased() == word,
              let name = Functions.allNames.first(where: { $0 == word }) ?? Functions.allNames.first(where: { $0.lowercased() == word })
        else { return false }
        entry.removeSubrange((cursor - word.count)..<cursor)
        cursor -= word.count
        let token = name + "("
        entry.insert(contentsOf: token, at: cursor)
        cursor += token.count
        store.save()
        return true
    }

    /// Typed symbols that have no keypad key and are pasted straight in, like a menu item would be.
    static let directTokens: [Character: String] = [
        "!": "!", "%": "%", "<": "<", ">": ">", "=": "=", "≠": "≠", "≤": "≤", "≥": "≥",
        "_": "_", "'": "'", "°": "°", "²": "²", "³": "³", "&": "and", "|": "or",
    ]

    /// Inserts a token into whichever entry line is being edited. Returns false if no line is.
    private func insertToken(_ s: String) -> Bool {
        guard entryHasCursor else { return false }
        if screen == .home, runner == nil {
            historyIndex = nil
            clearHistorySelection()
        }
        insert(s)
        store.save()
        return true
    }

    /// Keypad key (and modifier) that produces a typed character.
    static func hardwareMap(_ c: Character) -> (KeyID, Modifier)? {
        switch c {
        case "0": return (.zero, .none)
        case "1": return (.one, .none)
        case "2": return (.two, .none)
        case "3": return (.three, .none)
        case "4": return (.four, .none)
        case "5": return (.five, .none)
        case "6": return (.six, .none)
        case "7": return (.seven, .none)
        case "8": return (.eight, .none)
        case "9": return (.nine, .none)
        case ".": return (.dot, .none)
        case "+": return (.plus, .none)
        case "-", "−": return (.minus, .none)
        case "~", "⁻": return (.negate, .none)
        case "*", "×": return (.multiply, .none)
        case "/", "÷": return (.divide, .none)
        case "^": return (.power, .none)
        case "(": return (.lparen, .none)
        case ")": return (.rparen, .none)
        case ",": return (.comma, .none)
        case "{": return (.lparen, .second)
        case "}": return (.rparen, .second)
        case "[": return (.multiply, .second)
        case "]": return (.minus, .second)
        case "π": return (.power, .second)
        case "√": return (.square, .second)
        case "θ": return (.three, .alpha)
        case "i": return (.dot, .second)        // imaginary unit; uppercase I is the variable
        case "e": return (.divide, .second)     // Euler's e; uppercase E is the variable
        case " ": return (.zero, .alpha)
        case "\"": return (.plus, .alpha)
        case ":": return (.dot, .alpha)
        case "?": return (.negate, .alpha)
        default:
            guard c.isASCII, c.isLetter else { return nil }
            let letter = String(c).uppercased()
            guard let spec = Keymap.keys.first(where: { $0.alpha == letter }) else { return nil }
            return (spec.id, .alpha)
        }
    }
}
