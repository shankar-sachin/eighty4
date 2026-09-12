import Foundation

/// MathPrint templates live inside ordinary entry text as private-use characters, so every existing
/// string path (history, entries, Y=, programs) carries them unchanged. The tokenizer turns them into
/// tokens and `MathLayout` draws them stacked on the home screen.
///
/// Two families: fraction / Un/d / piecewise have their own delimiters and tokens; the function-style
/// templates (`Kind`: exponent, radicals, logBASE, abs, Σ, d/dx, ∫) share `slotSep`/`tplClose` and are
/// flattened to their flat call (`2^(3)`, `Σ(X,X,1,10)`) before tokenizing.
enum MathPrint {
    static let fracOpen: Character = "\u{E000}"    // ⌈numerator
    static let fracSep: Character = "\u{E001}"     // numerator⌉/⌊denominator
    static let fracClose: Character = "\u{E002}"   // denominator⌋
    static let mixedOpen: Character = "\u{E003}"   // Un/d: whole-number slot up to the following fracOpen
    static let stackOpen: Character = "\u{E005}"   // piecewise( rows
    static let rowSep: Character = "\u{E006}"
    static let stackClose: Character = "\u{E007}"
    static let colSep: Character = "\u{E004}"      // expression ▸ condition gap inside a piecewise row
    static let slotSep: Character = "\u{E00F}"     // between the slots of a function-style template
    static let tplClose: Character = "\u{E00E}"    // end of a function-style template

    /// Function-style templates. Slots are stored in the order the cursor visits them on the CE.
    enum Kind: CaseIterable {
        case exp        // base outside, raised exponent
        case sqrt       // √ radicand
        case root       // index, radicand (ˣ√ / ³√)
        case logBase    // base, argument
        case abs        // |argument|
        case sum        // variable, start, end, expression
        case deriv      // variable, expression, value
        case integral   // lower, upper, expression, variable

        var open: Character {
            switch self {
            case .exp: return "\u{E010}"
            case .sqrt: return "\u{E011}"
            case .root: return "\u{E012}"
            case .logBase: return "\u{E013}"
            case .abs: return "\u{E014}"
            case .sum: return "\u{E015}"
            case .deriv: return "\u{E016}"
            case .integral: return "\u{E017}"
            }
        }

        var slotCount: Int {
            switch self {
            case .exp, .sqrt, .abs: return 1
            case .root, .logBase: return 2
            case .deriv: return 3
            case .sum, .integral: return 4
            }
        }

        /// One-character stand-in on screens that draw plain cells.
        var fallbackGlyph: String {
            switch self {
            case .exp: return "^"
            case .sqrt, .root: return "√"
            case .logBase: return "l"
            case .abs: return "|"
            case .sum: return "Σ"
            case .deriv: return "d"
            case .integral: return "∫"
            }
        }

        static let opens: Set<Character> = Set(allCases.map(\.open))
        static func of(_ c: Character) -> Kind? { opens.contains(c) ? allCases.first { $0.open == c } : nil }

        /// The flat call for slot texts given in cursor order.
        func flat(_ s: [String]) -> String {
            func slot(_ i: Int) -> String { i < s.count ? s[i] : "" }
            switch self {
            case .exp: return "^(" + slot(0) + ")"
            case .sqrt: return "√(" + slot(0) + ")"
            case .root: return "(" + slot(0) + ")ˣ√(" + slot(1) + ")"
            case .logBase: return slot(0).isEmpty ? "log(" + slot(1) + ")" : "logBASE(" + slot(1) + "," + slot(0) + ")"   // empty base = 10, as on the Evo's log key
            case .abs: return "abs(" + slot(0) + ")"
            case .sum: return "Σ(" + slot(3) + "," + slot(0) + "," + slot(1) + "," + slot(2) + ")"
            case .deriv: return "nDeriv(" + slot(1) + "," + slot(0) + "," + slot(2) + ")"
            case .integral: return "fnInt(" + slot(2) + "," + slot(3) + "," + slot(0) + "," + slot(1) + ")"
            }
        }
    }

    static let templateChars: Set<Character> = Set([fracOpen, fracSep, fracClose, mixedOpen, stackOpen, rowSep, stackClose, colSep, slotSep, tplClose]).union(Kind.opens)

    static func fraction(_ n: String, _ d: String) -> String { "\(fracOpen)\(n)\(fracSep)\(d)\(fracClose)" }
    static func mixed(_ whole: String, _ n: String, _ d: String) -> String { "\(mixedOpen)\(whole)" + fraction(n, d) }
    static func piecewise(rows: Int) -> String {
        "\(stackOpen)" + (0..<max(1, rows)).map { _ in "\(colSep)" }.joined(separator: "\(rowSep)") + "\(stackClose)"
    }
    /// A function-style template with the given slot texts (missing ones are empty).
    static func template(_ kind: Kind, _ slots: [String] = []) -> String {
        var s = slots
        while s.count < kind.slotCount { s.append("") }
        return String(kind.open) + s.joined(separator: String(slotSep)) + String(tplClose)
    }

    static let fractionTemplate = fraction("", "")
    static let mixedTemplate = mixed("", "", "")

    /// Flat token → stacked template, for keys and menu items on the home screen in MATHPRINT mode.
    static let templates: [(flat: String, template: String)] = [
        ("^", template(.exp)), ("√(", template(.sqrt)), ("ˣ√", template(.root)), ("³√(", template(.root, ["3"])),
        ("logBASE(", template(.logBase)), ("abs(", template(.abs)), ("Σ(", template(.sum)),
        ("nDeriv(", template(.deriv)), ("fnInt(", template(.integral)),
        ("e^(", "e" + template(.exp)), ("10^(", "10" + template(.exp)),
        ("/", fractionTemplate), ("_", mixedTemplate),   // the Evo's n/d key and the FRAC menu
    ]
    static func template(for flat: String) -> String { templates.first { $0.flat == flat }?.template ?? flat }

    static func isTemplate(_ c: Character) -> Bool { templateChars.contains(c) }
    static func containsTemplate(_ s: String) -> Bool { s.contains(where: isTemplate) }
    static func containsTemplate(_ s: [Character]) -> Bool { s.contains(where: isTemplate) }
    /// Nesting opens (a mixed number's whole slot is not one).
    static func isOpen(_ c: Character) -> Bool { c == fracOpen || c == stackOpen || Kind.opens.contains(c) }
    static func isClose(_ c: Character) -> Bool { c == fracClose || c == stackClose || c == tplClose }
    static func isSep(_ c: Character) -> Bool { c == fracSep || c == rowSep || c == colSep || c == slotSep }
    static func hasFunctionTemplate(_ s: String) -> Bool { s.contains { Kind.opens.contains($0) } }

    /// What a menu inserts outside the home screen: the CLASSIC token for an empty template, otherwise the flat text.
    static func classicInsert(_ s: String) -> String {
        if s == fractionTemplate { return "/" }
        if s == mixedTemplate { return "_" }
        if s.first == stackOpen { return "piecewise(" }
        if let t = templates.first(where: { $0.template == s }) { return t.flat }
        return classic(s)
    }

    /// Single-row stand-in for editors that draw plain cells: ⌈1⌉/⌊2⌋ → (1)/(2), piecewise rows → piecewise(a,b,c,d),
    /// function templates → their flat call.
    static func classic(_ s: String) -> String {
        var out = ""
        for c in flatten(s) {
            switch c {
            case fracOpen: out += "("
            case fracSep: out += ")/("
            case fracClose: out += ")"
            case mixedOpen: break
            case stackOpen: out += "piecewise("
            case rowSep, colSep, slotSep: out += ","
            case stackClose, tplClose: out += ")"
            default: out.append(c)
            }
        }
        return out
    }

    /// Function-style templates as flat calls; fraction and piecewise delimiters stay for the tokenizer.
    static func flatten(_ s: String) -> String {
        guard hasFunctionTemplate(s) else { return s }
        let chars = Array(s)
        return flatten(chars, from: 0, to: chars.count)
    }

    private static func flatten(_ chars: [Character], from: Int, to: Int) -> String {
        var out = ""
        var i = from
        while i < to {
            let c = chars[i]
            if let kind = Kind.of(c), let close = matchingClose(in: chars, from: i), close < to {
                let slots = slotRanges(in: chars, from: i).map { flatten(chars, from: $0.lowerBound, to: $0.upperBound) }
                out += kind.flat(slots)
                i = close + 1
            } else {
                out.append(c)
                i += 1
            }
        }
        return out
    }

    // MARK: - Structure

    /// Index of the delimiter that closes the template opened at `open` (matching nesting), or nil.
    static func matchingClose(in chars: [Character], from open: Int) -> Int? {
        var depth = 0
        var i = open
        while i < chars.count {
            let c = chars[i]
            if isOpen(c) { depth += 1 }
            else if isClose(c) {
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
            if isOpen(c) { depth += 1 }
            else if isClose(c) { depth -= 1; if depth == 0 { return nil } }
            else if c == fracSep, depth == 1 { return i }
            i += 1
        }
        return nil
    }

    /// Separators at nesting depth 1 of the template opened at `open`; `only` restricts the kind (all when nil).
    static func separators(in chars: [Character], from open: Int, to close: Int, only: Character? = nil) -> [Int] {
        var depth = 0
        var out: [Int] = []
        for i in open...close {
            let c = chars[i]
            if isOpen(c) { depth += 1 }
            else if isClose(c) { depth -= 1 }
            else if depth == 1, isSep(c), only == nil || c == only { out.append(i) }
        }
        return out
    }

    /// Row separators at nesting depth 1 of the stack opened at `open`.
    static func rowSeparators(in chars: [Character], from open: Int, to close: Int) -> [Int] {
        separators(in: chars, from: open, to: close, only: rowSep)
    }

    /// Slot ranges of the template starting at `open`, in cursor order (a mixed number's whole slot comes first).
    static func slotRanges(in chars: [Character], from open: Int) -> [Range<Int>] {
        guard open < chars.count else { return [] }
        if chars[open] == mixedOpen {
            guard let f = fracOpenOfMixed(in: chars, at: open) else { return [] }
            return [(open + 1)..<f] + slotRanges(in: chars, from: f)
        }
        guard isOpen(chars[open]), let close = matchingClose(in: chars, from: open) else { return [] }
        let seps = separators(in: chars, from: open, to: close)
        let starts = [open + 1] + seps.map { $0 + 1 }
        let ends = seps + [close]
        return zip(starts, ends).map { $0..<$1 }
    }

    /// Where the cursor lands after inserting the template at `open`: its first empty slot, else its first slot.
    static func firstEmptySlot(in chars: [Character], from open: Int) -> Int {
        slotRanges(in: chars, from: open).first { $0.isEmpty }?.lowerBound ?? open + 1
    }

    /// The whole template (open…close, plus a leading Un/d whole slot) that the delimiter at `pos` belongs to.
    /// DEL on any delimiter removes the template as a unit, as the CE does.
    static func templateRange(in chars: [Character], containing pos: Int) -> Range<Int>? {
        guard pos < chars.count, isTemplate(chars[pos]) else { return nil }
        var open = pos
        if isSep(chars[pos]) || isClose(chars[pos]) {
            var depth = 0
            var i = pos - 1
            while i >= 0 {
                let c = chars[i]
                if isClose(c) { depth += 1 }
                else if isOpen(c) {
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
                if isClose(c) { depth += 1 }
                else if isOpen(c) { depth -= 1 }
                else if depth == 0, c == mixedOpen { start = i; break }
                else if depth == 0, isSep(c) { break }
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
            if isOpen(c) { depth += 1 }
            else if isClose(c) { if depth == 0 { return nil }; depth -= 1 }
            else if depth == 0, isSep(c) || c == mixedOpen { return nil }
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
        /// Exponents, indices, bounds: drawn in the small font.
        var small = false
    }
    struct Bar: Equatable { let x0: Double; let x1: Double; let y: Double }
    struct Brace: Equatable { let x: Double; let y: Double; let rows: Int }
    /// Drawn symbols that span cells: the radical sign, |abs| bars, a big Σ or ∫.
    struct Decor: Equatable {
        enum Kind { case radical, vbar, sigma, integral }
        let kind: Kind
        let x: Double
        let y: Double
        let w: Double
        let h: Double
    }

    /// One screen row group: `height` cell rows tall.
    struct Row {
        var glyphs: [Glyph] = []
        var bars: [Bar] = []
        var braces: [Brace] = []
        var decors: [Decor] = []
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
        for e in elements {
            if used + e.box.width > width, !current.isEmpty { flush(endIndex: e.first) }
            current.append((e.first, e.box))
            used += e.box.width
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
        var decors: [Decor] = []
        var slots: [Int: (x: Double, y: Double)] = [:]

        mutating func place(_ b: Box, x: Double, y: Double) {
            glyphs += b.glyphs.map { Glyph(ch: $0.ch, x: $0.x + x, y: $0.y + y, placeholder: $0.placeholder, small: $0.small) }
            bars += b.bars.map { Bar(x0: $0.x0 + x, x1: $0.x1 + x, y: $0.y + y) }
            braces += b.braces.map { Brace(x: $0.x + x, y: $0.y + y, rows: $0.rows) }
            decors += b.decors.map { Decor(kind: $0.kind, x: $0.x + x, y: $0.y + y, w: $0.w, h: $0.h) }
            for (k, v) in b.slots { slots[k] = (v.x + x, v.y + y) }
        }

        /// The same box with every glyph in the small font.
        func small() -> Box {
            var b = self
            b.glyphs = glyphs.map { Glyph(ch: $0.ch, x: $0.x, y: $0.y, placeholder: $0.placeholder, small: true) }
            return b
        }

        var row: Row {
            Row(glyphs: glyphs, bars: bars, braces: braces, decors: decors, width: width, height: max(1, Int(height.rounded(.up))), slots: slots)
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
            } else if let kind = MathPrint.Kind.of(c), let close = MathPrint.matchingClose(in: chars, from: i), close < to {
                out.append(Element(first: i, box: templateBox(kind, chars, open: i, close: close)))
                i = close + 1
            } else {
                out.append(Element(first: i, box: glyphBox(c == MathPrint.colSep ? " " : (MathPrint.isTemplate(c) ? "?" : c))))
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
        var out = join(items.map(\.1))
        var x = 0.0
        for (first, b) in items {
            if out.slots[first] == nil { out.slots[first] = (x, out.axis - 0.5) }
            x += Double(b.width)
        }
        if let e = endIndex { out.slots[e] = (x, out.axis - 0.5) }
        return (out, out.row)
    }

    /// Joins boxes left to right on a shared axis, carrying their cursor slots along.
    private static func join(_ boxes: [Box]) -> Box {
        var out = Box()
        let axis = boxes.map(\.axis).max() ?? 0.5
        let below = boxes.map { $0.height - $0.axis }.max() ?? 0.5
        out.axis = axis
        out.height = axis + below
        var x = 0.0
        for b in boxes {
            out.place(b, x: x, y: axis - b.axis)
            x += Double(b.width)
        }
        out.width = Int(x)
        return out
    }

    private static func glyphBox(_ ch: Character, small: Bool = false) -> Box {
        var box = Box()
        box.width = 1
        box.glyphs = [Glyph(ch: ch, x: 0, y: 0, placeholder: false, small: small)]
        return box
    }

    /// Fixed text that is part of a template (log, d, parentheses): no cursor slots.
    private static func text(_ s: String, small: Bool = false) -> Box { join(s.map { glyphBox($0, small: small) }) }

    private static func fractionBox(_ chars: [Character], open: Int, sep: Int, close: Int) -> Box {
        fraction(num: sequence(chars, from: open + 1, to: sep), den: sequence(chars, from: sep + 1, to: close))
    }

    private static func fraction(num: Box, den: Box) -> Box {
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

    // MARK: Function-style templates

    private static func templateBox(_ kind: MathPrint.Kind, _ chars: [Character], open: Int, close: Int) -> Box {
        let ranges = MathPrint.slotRanges(in: chars, from: open)
        let slots: [Box] = (0..<kind.slotCount).map { i in
            i < ranges.count ? sequence(chars, from: ranges[i].lowerBound, to: ranges[i].upperBound) : sequence(chars, from: close, to: close)
        }
        switch kind {
        case .exp:
            return raised(slots[0])
        case .sqrt:
            return radical(slots[0])
        case .root:
            let idx = slots[0].small(), rad = radical(slots[1])
            var box = Box()
            box.width = idx.width + rad.width
            box.axis = rad.axis + 0.5
            box.height = max(rad.height + 0.5, idx.height)
            box.place(idx, x: 0, y: 0)
            box.place(rad, x: Double(idx.width), y: 0.5)
            return box
        case .logBase:
            let base = slots[0].small()
            let arg = join([text("("), slots[1], text(")")])
            var box = Box()
            box.axis = arg.axis
            box.height = max(arg.height, box.axis + base.height)
            box.place(text("log"), x: 0, y: box.axis - 0.5)
            box.place(base, x: 3, y: box.axis)                       // subscript: hangs below the axis
            box.place(arg, x: Double(3 + base.width), y: 0)
            box.width = 3 + base.width + arg.width
            return box
        case .abs:
            let s = slots[0]
            var box = Box()
            box.width = s.width + 2
            box.height = s.height
            box.axis = s.axis
            box.place(s, x: 1, y: 0)
            box.decors = [Decor(kind: .vbar, x: 0, y: 0, w: 1, h: s.height), Decor(kind: .vbar, x: Double(s.width + 1), y: 0, w: 1, h: s.height)]
            return box
        case .sum:
            let lower = join([slots[0], text("="), slots[1]]).small()
            return bigOperator(.sigma, lower: lower, upper: slots[2].small(), body: join([text("("), slots[3], text(")")]))
        case .integral:
            return bigOperator(.integral, lower: slots[0].small(), upper: slots[1].small(),
                               body: join([text("("), slots[2], text(")d"), slots[3]]))
        case .deriv:
            let v = slots[0]
            var mirror = v
            mirror.slots = [:]                                       // the |X= repeats the variable; only d/dX takes the cursor
            let frac = fraction(num: text("d"), den: join([text("d"), v]))
            let body = join([text("("), slots[1], text(")")])
            let at = join([mirror, text("="), slots[2]]).small()
            var box = Box()
            box.axis = max(frac.axis, body.axis)
            let below = max(frac.height - frac.axis, body.height - body.axis)
            box.height = max(box.axis + below, box.axis + at.height)
            box.place(frac, x: 0, y: box.axis - frac.axis)
            box.place(body, x: Double(frac.width), y: box.axis - body.axis)
            let barX = Double(frac.width + body.width)
            box.decors = [Decor(kind: .vbar, x: barX, y: box.axis - body.axis, w: 1, h: body.height)]
            box.place(at, x: barX + 1, y: box.axis)
            box.width = frac.width + body.width + 1 + at.width
            return box
        }
    }

    /// An exponent: small, with its bottom edge on the centre line of whatever precedes it.
    private static func raised(_ s: Box) -> Box {
        var box = s.small()
        box.axis = s.height
        box.height = s.height + 0.5
        return box
    }

    /// √ sign with a vinculum over the radicand.
    private static func radical(_ s: Box) -> Box {
        var box = Box()
        box.width = s.width + 1
        box.height = s.height
        box.axis = s.axis
        box.place(s, x: 1, y: 0)
        box.decors = [Decor(kind: .radical, x: 0, y: 0, w: 1, h: s.height)]
        box.bars = [Bar(x0: 1, x1: Double(box.width), y: 0.08)] + box.bars
        return box
    }

    /// Σ / ∫ with the upper bound above, the lower bound below, and the body to the right on the operator's row.
    private static func bigOperator(_ op: Decor.Kind, lower: Box, upper: Box, body: Box) -> Box {
        let w = max(lower.width, upper.width, 2)
        var box = Box()
        box.axis = max(upper.height + 0.5, body.axis)
        box.height = max(box.axis + 0.5 + lower.height, box.axis + body.height - body.axis)
        box.place(upper, x: Double(w - upper.width) / 2, y: box.axis - 0.5 - upper.height)
        box.decors = [Decor(kind: op, x: 0, y: box.axis - 0.5, w: Double(w), h: 1)]
        box.place(lower, x: Double(w - lower.width) / 2, y: box.axis + 0.5)
        box.place(body, x: Double(w), y: box.axis - body.axis)
        box.width = w + body.width
        return box
    }
}
