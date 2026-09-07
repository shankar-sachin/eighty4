import Foundation

/// MathPrint templates live inside ordinary entry text as private-use characters, so every existing
/// string path (history, entries, Y=, programs) carries them unchanged. The tokenizer turns them into
/// tokens and `MathLayout` draws them stacked on the home screen.
enum MathPrint {
    static let fracOpen: Character = "\u{E000}"    // ⌈numerator
    static let fracSep: Character = "\u{E001}"     // numerator⌉/⌊denominator
    static let fracClose: Character = "\u{E002}"   // denominator⌋
    static let mixedOpen: Character = "\u{E003}"   // Un/d: whole-number slot up to the following fracOpen
    static let stackOpen: Character = "\u{E005}"   // piecewise( rows
    static let rowSep: Character = "\u{E006}"
    static let stackClose: Character = "\u{E007}"
    static let colSep: Character = "\u{E004}"      // expression ▸ condition gap inside a piecewise row

    static let templateChars: Set<Character> = [fracOpen, fracSep, fracClose, mixedOpen, stackOpen, rowSep, stackClose, colSep]

    static func fraction(_ n: String, _ d: String) -> String { "\(fracOpen)\(n)\(fracSep)\(d)\(fracClose)" }
    static func mixed(_ whole: String, _ n: String, _ d: String) -> String { "\(mixedOpen)\(whole)" + fraction(n, d) }
    static func piecewise(rows: Int) -> String {
        "\(stackOpen)" + (0..<max(1, rows)).map { _ in "\(colSep)" }.joined(separator: "\(rowSep)") + "\(stackClose)"
    }

    static let fractionTemplate = fraction("", "")
    static let mixedTemplate = mixed("", "", "")

    static func isTemplate(_ c: Character) -> Bool { templateChars.contains(c) }
    static func containsTemplate(_ s: String) -> Bool { s.contains(where: isTemplate) }

    /// What a menu inserts outside the home screen: the CLASSIC token for an empty template, otherwise the flat text.
    static func classicInsert(_ s: String) -> String {
        if s == fractionTemplate { return "/" }
        if s == mixedTemplate { return "_" }
        if s.first == stackOpen { return "piecewise(" }
        return classic(s)
    }

    /// Single-row stand-in for editors that draw plain cells: ⌈1⌉/⌊2⌋ → (1)/(2), piecewise rows → piecewise(a,b,c,d).
    static func classic(_ s: String) -> String {
        var out = ""
        for c in s {
            switch c {
            case fracOpen: out += "("
            case fracSep: out += ")/("
            case fracClose: out += ")"
            case mixedOpen: break
            case stackOpen: out += "piecewise("
            case rowSep, colSep: out += ","
            case stackClose: out += ")"
            default: out.append(c)
            }
        }
        return out
    }

    /// Index of the delimiter that closes the template opened at `open` (matching nesting), or nil.
    static func matchingClose(in chars: [Character], from open: Int) -> Int? {
        var depth = 0
        var i = open
        while i < chars.count {
            let c = chars[i]
            if c == fracOpen || c == stackOpen { depth += 1 }
            else if c == fracClose || c == stackClose {
                depth -= 1
                if depth == 0 { return i }
            }
            i += 1
        }
        return nil
    }

    /// Index of the fracSep belonging to the fraction opened at `open`, or nil.
    static func separator(in chars: [Character], from open: Int) -> Int? {
        var depth = 0
        var i = open
        while i < chars.count {
            let c = chars[i]
            if c == fracOpen || c == stackOpen { depth += 1 }
            else if c == fracClose || c == stackClose { depth -= 1; if depth == 0 { return nil } }
            else if c == fracSep, depth == 1 { return i }
            i += 1
        }
        return nil
    }

    /// Row separators at nesting depth 1 of the stack opened at `open`.
    static func rowSeparators(in chars: [Character], from open: Int, to close: Int) -> [Int] {
        var depth = 0
        var out: [Int] = []
        for i in open...close {
            let c = chars[i]
            if c == fracOpen || c == stackOpen { depth += 1 }
            else if c == fracClose || c == stackClose { depth -= 1 }
            else if c == rowSep, depth == 1 { out.append(i) }
        }
        return out
    }

    /// The whole template (open…close, plus a leading Un/d whole slot) that the delimiter at `pos` belongs to.
    /// DEL on any delimiter removes the template as a unit, as the CE does.
    static func templateRange(in chars: [Character], containing pos: Int) -> Range<Int>? {
        guard pos < chars.count, isTemplate(chars[pos]) else { return nil }
        var open = pos
        if chars[pos] == fracSep || chars[pos] == fracClose || chars[pos] == rowSep || chars[pos] == stackClose || chars[pos] == colSep {
            var depth = 0
            var i = pos - 1
            while i >= 0 {
                let c = chars[i]
                if c == fracClose || c == stackClose { depth += 1 }
                else if c == fracOpen || c == stackOpen {
                    if depth == 0 { break }
                    depth -= 1
                }
                i -= 1
            }
            guard i >= 0 else { return pos..<(pos + 1) }
            open = i
        }
        if chars[open] == mixedOpen {
            guard let f = fracOpenOfMixed(in: chars, at: open), let close = matchingClose(in: chars, from: f) else { return open..<(open + 1) }
            return open..<(close + 1)
        }
        guard let close = matchingClose(in: chars, from: open) else { return open..<(open + 1) }
        var start = open
        if chars[open] == fracOpen {
            // A fraction that carries a whole-number slot goes with it.
            var i = open - 1
            var depth = 0
            while i >= 0 {
                let c = chars[i]
                if c == fracClose || c == stackClose { depth += 1 }
                else if c == fracOpen || c == stackOpen { depth -= 1 }
                else if depth == 0, c == mixedOpen { start = i; break }
                else if depth == 0, c == fracSep || c == rowSep || c == colSep { break }
                i -= 1
            }
            if start != open, fracOpenOfMixed(in: chars, at: start) != open { start = open }
        }
        return start..<(close + 1)
    }

    /// The fracOpen that a mixedOpen at `pos` feeds (first one at the same depth).
    static func fracOpenOfMixed(in chars: [Character], at pos: Int) -> Int? {
        var depth = 0
        var i = pos + 1
        while i < chars.count {
            let c = chars[i]
            if c == fracOpen, depth == 0 { return i }
            if c == stackOpen || c == fracOpen { depth += 1 }
            else if c == stackClose || c == fracClose { if depth == 0 { return nil }; depth -= 1 }
            else if depth == 0, c == fracSep || c == rowSep || c == colSep || c == mixedOpen { return nil }
            i += 1
        }
        return nil
    }
}

/// Lays text with MathPrint templates out on the cell grid. Positions are in cells (x) and rows (y);
/// rows may be fractional so text next to a fraction sits on its bar.
struct MathLayout {
    struct Glyph: Equatable {
        let ch: Character
        let x: Double
        let y: Double
        /// Empty template slot drawn as a dotted box.
        let placeholder: Bool
    }
    struct Bar: Equatable { let x0: Double; let x1: Double; let y: Double }
    struct Brace: Equatable { let x: Double; let y: Double; let rows: Int }

    /// One screen row group: `height` cell rows tall.
    struct Row {
        var glyphs: [Glyph] = []
        var bars: [Bar] = []
        var braces: [Brace] = []
        var width: Int = 0
        var height: Int = 1
        /// Cursor cell (top-left) for every character index this row holds; a cursor is one row tall.
        var slots: [Int: (x: Double, y: Double)] = [:]
    }

    var rows: [Row]
    var totalRows: Int { rows.reduce(0) { $0 + $1.height } }
    var isPlain: Bool

    /// Cursor position for a character index: the layout row it is in, and the cell inside that row.
    func cursor(at index: Int) -> (row: Int, x: Double, y: Double) {
        for (i, r) in rows.enumerated() { if let s = r.slots[index] { return (i, s.x, s.y) } }
        let last = rows.count - 1
        return (last, Double(rows[last].width), Double(rows[last].height - 1))
    }

    /// Row offset (in cell rows) at which layout row `i` starts.
    func rowStart(_ i: Int) -> Int { rows.prefix(i).reduce(0) { $0 + $1.height } }

    static func layout(_ text: String, width: Int) -> MathLayout { layout(Array(text), width: width) }

    static func layout(_ chars: [Character], width: Int) -> MathLayout {
        if !chars.contains(where: MathPrint.isTemplate) {
            // Plain text: wrap by character like a classic screen.
            var rows: [Row] = []
            var i = 0
            repeat {
                var row = Row()
                let end = min(chars.count, i + width)
                for j in i..<end {
                    row.glyphs.append(Glyph(ch: chars[j], x: Double(j - i), y: 0, placeholder: false))
                    row.slots[j] = (Double(j - i), 0)
                }
                row.width = end - i
                row.slots[end] = (Double(end - i), 0)
                rows.append(row)
                i = end
            } while i < chars.count
            return MathLayout(rows: rows, isPlain: true)
        }
        let elements = Self.elements(chars, from: 0, to: chars.count)
        var rows: [Row] = []
        var current: [(Int, Box)] = []
        var used = 0
        func flush(endIndex: Int) {
            let box = Self.assemble(current, endIndex: endIndex)
            rows.append(box.row)
            current = []
            used = 0
        }
        for (i, e) in elements.enumerated() {
            if used + e.box.width > width, !current.isEmpty { flush(endIndex: e.first) }
            current.append((e.first, e.box))
            used += e.box.width
            _ = i
        }
        flush(endIndex: chars.count)
        return MathLayout(rows: rows, isPlain: false)
    }

    // MARK: - Boxes

    /// A laid-out fragment: `axis` is the row (from the top) that the fraction bar / text centre sits on.
    struct Box {
        var width: Int = 0
        var height: Double = 1
        var axis: Double = 0.5
        var glyphs: [Glyph] = []
        var bars: [Bar] = []
        var braces: [Brace] = []
        var slots: [Int: (x: Double, y: Double)] = [:]

        mutating func place(_ b: Box, x: Double, y: Double) {
            glyphs += b.glyphs.map { Glyph(ch: $0.ch, x: $0.x + x, y: $0.y + y, placeholder: $0.placeholder) }
            bars += b.bars.map { Bar(x0: $0.x0 + x, x1: $0.x1 + x, y: $0.y + y) }
            braces += b.braces.map { Brace(x: $0.x + x, y: $0.y + y, rows: $0.rows) }
            for (k, v) in b.slots { slots[k] = (v.x + x, v.y + y) }
        }

        var row: Row {
            Row(glyphs: glyphs, bars: bars, braces: braces, width: width, height: max(1, Int(height.rounded(.up))), slots: slots)
        }
    }

    private struct Element {
        let first: Int
        let box: Box
    }

    /// Splits `chars[from..<to]` into atomic elements: characters and whole templates.
    private static func elements(_ chars: [Character], from: Int, to: Int) -> [Element] {
        var out: [Element] = []
        var i = from
        while i < to {
            let c = chars[i]
            if c == MathPrint.fracOpen, let sep = MathPrint.separator(in: chars, from: i), let close = MathPrint.matchingClose(in: chars, from: i), close < to {
                out.append(Element(first: i, box: fractionBox(chars, open: i, sep: sep, close: close)))
                i = close + 1
            } else if c == MathPrint.mixedOpen, let f = MathPrint.fracOpenOfMixed(in: chars, at: i), let sep = MathPrint.separator(in: chars, from: f),
                      let close = MathPrint.matchingClose(in: chars, from: f), close < to {
                let whole = sequence(chars, from: i + 1, to: f)
                let frac = fractionBox(chars, open: f, sep: sep, close: close)
                var box = assemble([(i + 1, whole), (f, frac)], endIndex: nil).box
                box.slots[i] = (0, box.axis - 0.5)   // the cursor "before" the mixed number sits at its left edge
                out.append(Element(first: i, box: box))
                i = close + 1
            } else if c == MathPrint.stackOpen, let close = MathPrint.matchingClose(in: chars, from: i), close < to {
                out.append(Element(first: i, box: stackBox(chars, open: i, close: close)))
                i = close + 1
            } else {
                var box = Box()
                box.width = 1
                box.glyphs = [Glyph(ch: c == MathPrint.colSep ? " " : (MathPrint.isTemplate(c) ? "?" : c), x: 0, y: 0, placeholder: false)]
                out.append(Element(first: i, box: box))
                i += 1
            }
        }
        return out
    }

    /// Lays a run out horizontally; an empty run becomes a placeholder box.
    private static func sequence(_ chars: [Character], from: Int, to: Int) -> Box {
        if from >= to {
            var box = Box()
            box.width = 1
            box.glyphs = [Glyph(ch: "□", x: 0, y: 0, placeholder: true)]
            box.slots[from] = (0, 0)
            return box
        }
        return assemble(elements(chars, from: from, to: to).map { ($0.first, $0.box) }, endIndex: to).box
    }

    /// Joins boxes left to right on a shared axis. `endIndex` gets the cursor slot after the last box.
    private static func assemble(_ items: [(Int, Box)], endIndex: Int?) -> (box: Box, row: Row) {
        var out = Box()
        let axis = items.map(\.1.axis).max() ?? 0.5
        let below = items.map { $0.1.height - $0.1.axis }.max() ?? 0.5
        out.axis = axis
        out.height = axis + below
        var x = 0.0
        for (first, b) in items {
            out.place(b, x: x, y: axis - b.axis)
            if out.slots[first] == nil { out.slots[first] = (x, axis - 0.5) }
            x += Double(b.width)
        }
        out.width = Int(x)
        if let e = endIndex { out.slots[e] = (x, axis - 0.5) }
        return (out, out.row)
    }

    private static func fractionBox(_ chars: [Character], open: Int, sep: Int, close: Int) -> Box {
        let num = sequence(chars, from: open + 1, to: sep)
        let den = sequence(chars, from: sep + 1, to: close)
        var box = Box()
        box.width = max(num.width, den.width)
        box.axis = num.height
        box.height = num.height + den.height
        box.place(num, x: Double(box.width - num.width) / 2, y: 0)
        box.place(den, x: Double(box.width - den.width) / 2, y: num.height)
        box.bars = [Bar(x0: 0, x1: Double(box.width), y: num.height)] + box.bars
        return box
    }

    private static func stackBox(_ chars: [Character], open: Int, close: Int) -> Box {
        let seps = MathPrint.rowSeparators(in: chars, from: open, to: close)
        var starts = [open + 1] + seps.map { $0 + 1 }
        let ends = seps + [close]
        if starts.count > ends.count { starts = Array(starts.prefix(ends.count)) }
        let rows = zip(starts, ends).map { sequence(chars, from: $0, to: $1) }
        var box = Box()
        box.width = (rows.map(\.width).max() ?? 1) + 1
        var y = 0.0
        for r in rows {
            box.place(r, x: 1, y: y)
            y += r.height
        }
        box.height = max(1, y)
        box.axis = box.height / 2
        box.braces = [Brace(x: 0, y: 0, rows: max(1, Int(box.height.rounded(.up))))]
        return box
    }
}
