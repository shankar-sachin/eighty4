import SwiftUI

@main
struct Eighty4App: App {
    @State private var state = Eighty4App.makeState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(state)
                .preferredColorScheme(.dark)
        }
    }

    /// Launch arguments used for screenshot verification:
    ///   -demo <name>     scripts key presses (see DemoScripts) after wiping saved memory
    ///   -shell <name>    forces a shell colorway (e.g. radicalRed)
    private static func makeState() -> CalculatorState {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-demo") {
            VariableStore.wipe()
            let s = CalculatorState()
            if let c = shellArg(args) { s.shell = c }
            let name = i + 1 < args.count ? args[i + 1] : "home"
            DemoScripts.run(name, on: s)
            return s
        }
        let s = CalculatorState()
        if let c = shellArg(args) { s.shell = c }
        return s
    }

    private static func shellArg(_ args: [String]) -> ShellColor? {
        guard let i = args.firstIndex(of: "-shell"), i + 1 < args.count else { return nil }
        return ShellColor(rawValue: args[i + 1])
    }
}

enum DemoScripts {
    static func run(_ name: String, on s: CalculatorState) {
        func keys(_ k: [KeyID]) { k.forEach { s.press($0) } }
        let yeq: [KeyID] = [.yEquals, .xtn, .square, .minus, .four, .down, .two, .xtn, .plus, .one]
        switch name {
        case "home":
            keys([.two, .plus, .three, .multiply, .four, .enter, .second, .square, .two, .rparen, .enter, .one, .divide, .three, .enter, .second, .negate, .power, .two, .enter, .five, .second, .math, .enter, .two, .enter, .sin, .second, .power, .divide, .two, .second])
        case "math": keys([.math])
        case "mathnum": keys([.math, .right])
        case "mode": keys([.mode, .down, .down, .down])
        case "yeq": keys(yeq)
        case "graph": keys(yeq + [.zoom, .six])
        case "trace": keys(yeq + [.zoom, .six, .trace, .right, .right, .right, .right, .right, .right, .right, .right, .right, .right])
        case "calc": keys(yeq + [.zoom, .six, .second, .trace, .two, .one, .enter, .three, .enter, .two, .enter])
        case "table": keys(yeq + [.second, .graph, .down, .down, .right])
        case "window": keys([.window, .down, .down])
        case "catalog": keys([.second, .zero, .down, .down])
        case "matrix":
            keys([.second, .inverse, .right, .right, .enter, .two, .enter, .two, .enter, .one, .enter, .two, .enter, .three, .enter, .four, .enter])
        case "matrixcalc":
            keys([.second, .inverse, .right, .right, .enter, .two, .enter, .two, .enter, .one, .enter, .two, .enter, .three, .enter, .four, .enter, .second, .mode, .second, .inverse, .enter, .inverse, .enter, .second, .inverse, .enter, .square, .enter])
        case "stat":
            keys([.stat, .enter, .one, .enter, .two, .enter, .three, .enter, .four, .enter, .right, .two, .enter, .four, .enter, .five, .enter, .nine, .enter])
        case "statcalc":
            keys([.stat, .enter, .one, .enter, .two, .enter, .three, .enter, .four, .enter, .right, .two, .enter, .four, .enter, .five, .enter, .nine, .enter, .stat, .right, .four])
        case "geodash": keys([.apps, .enter])
        case "tetris": keys([.apps, .down, .enter])
        case "tvm": keys([.apps, .three, .three, .six, .zero, .enter, .six, .enter, .two, .five, .zero, .zero, .zero, .zero, .enter, .zero, .enter, .zero, .down, .one, .two, .enter, .one, .two, .enter, .up, .up, .up, .up, .alpha, .enter])
        case "off": keys([.second, .on])
        case "second": keys([.second])
        case "solver":
            // X²−4=0, solve for X from a guess of 1
            keys([.math, .up, .enter, .xtn, .square, .minus, .four, .enter, .one, .alpha, .enter])
        case "param":
            // MODE → PARAM, X1T=3cos(T), Y1T=3sin(T), ZStandard
            keys([.mode, .down, .down, .down, .down, .right, .enter, .second, .mode, .yEquals, .three, .cos, .xtn, .rparen, .down, .three, .sin, .xtn, .rparen, .zoom, .six])
        case "polar":
            keys([.mode, .down, .down, .down, .down, .right, .right, .enter, .second, .mode, .yEquals, .four, .cos, .three, .xtn, .rparen, .zoom, .six])
        case "seq":
            // u(n)=u(n−1)+2, u(nMin)=1
            keys([.mode, .down, .down, .down, .down, .right, .right, .right, .enter, .second, .mode, .yEquals, .down, .second, .seven, .lparen, .xtn, .minus, .one, .rparen, .plus, .two, .down, .one, .zoom, .six])
        case "ztest":
            // STAT TESTS 1:Z-Test, Stats input, μ0=5 σ=2 x̄=5.8 n=20, Calculate
            keys([.stat, .left, .enter, .right, .enter, .five, .enter, .two, .enter, .five, .dot, .eight, .enter, .two, .zero, .enter, .down, .enter])
        case "ztestdraw":
            keys([.stat, .left, .enter, .right, .enter, .five, .enter, .two, .enter, .five, .dot, .eight, .enter, .two, .zero, .enter, .down, .right, .enter])
        case "shade":
            keys([.zoom, .four, .second, .vars, .right, .enter, .negate, .one, .comma, .one, .rparen, .enter])
        case "zbox":
            keys(yeq + [.zoom, .six, .zoom, .one, .enter, .right, .right, .right, .right, .right, .right, .down, .down, .down, .down])
        case "prgmedit":
            // NEW program AB: ":Disp 5" / ":For(I,1,3" / ":Disp I×I" / ":End"
            keys([.prgm, .right, .right, .enter, .math, .apps, .enter, .one, .prgm, .right, .three, .five, .enter,
                  .prgm, .four, .alpha, .square, .comma, .one, .comma, .three, .enter,
                  .prgm, .right, .three, .alpha, .square, .multiply, .alpha, .square, .enter, .prgm, .seven])
        case "prgm":
            keys([.prgm, .right, .right, .enter, .math, .apps, .enter, .one, .prgm, .right, .three, .five, .enter,
                  .prgm, .four, .alpha, .square, .comma, .one, .comma, .three, .enter,
                  .prgm, .right, .three, .alpha, .square, .multiply, .alpha, .square, .enter, .prgm, .seven,
                  .second, .mode, .prgm, .three])
        case "seqyeq":
            keys([.mode, .down, .down, .down, .down, .right, .right, .right, .enter, .second, .mode, .yEquals, .down, .second, .seven, .lparen, .xtn, .minus, .one, .rparen, .plus, .two, .down, .one, .down])
        case "ztestedit":
            keys([.stat, .left, .enter, .right, .enter, .five, .enter, .two, .enter, .five, .dot, .eight, .enter, .two, .zero, .enter])
        case "plysmlt": keys([.apps, .eight, .enter, .right, .graph, .one, .enter, .negate, .three, .enter, .two, .graph])
        case "conics": keys([.apps, .six, .two, .one, .zero, .enter, .zero, .enter, .four, .enter, .two, .graph])
        case "probsim": keys([.apps, .nine, .two, .zoom, .zoom, .zoom])
        case "celsheet": keys([.apps, .five, .one, .enter, .two, .enter, .three, .enter, .alpha, .math, .one, .plus, .alpha, .math, .two, .plus, .alpha, .math, .three, .enter])
        case "mem": keys([.second, .plus, .two, .enter])
        case "inequalz":
            // Y₁ < X²−4 (F2), then X₁ > Y² (◀ onto the symbol, F4), GRAPH
            keys([.apps, .seven, .xtn, .square, .minus, .four, .window] + Array(repeating: .down, count: 10)
                 + [.alpha, .one, .square, .left, .trace, .graph])
        case "complex":
            keys([.lparen, .three, .plus, .two, .second, .dot, .rparen, .lparen, .one, .minus, .five, .second, .dot, .rparen, .enter,
                  .mode, .down, .down, .down, .down, .down, .down, .down, .right, .enter, .second, .mode,
                  .second, .square, .negate, .four, .rparen, .enter, .lparen, .negate, .eight, .rparen, .power, .lparen, .one, .divide, .three, .rparen, .enter,
                  .second, .lparen, .one, .plus, .second, .dot, .comma, .two, .second, .rparen, .multiply, .second, .dot, .enter])
        case "prgmlock":
            keys([.prgm, .right, .right, .enter, .math, .apps, .enter])   // NEW → AB → "Program Lock?"
        case "mathprint":
            // n/d 1/2 + n/d 1/4, then 7/2▶Frac as Un/d, then a 2-piece piecewise( on X
            keys([.math, .left, .one, .one, .right, .two, .right, .plus, .math, .left, .one, .one, .right, .four, .right, .enter,
                  .seven, .divide, .two, .math, .one, .enter,
                  .mode, .down, .down, .down, .down, .down, .down, .down, .down, .down, .right, .enter, .second, .mode,
                  .seven, .divide, .two, .math, .one, .enter,
                  .math, .up, .up, .enter, .two, .xtn, .square, .right, .xtn, .second, .math, .five, .zero, .right, .xtn, .right, .xtn, .second, .math, .four, .zero, .enter])
        case "mathprintedit":
            keys([.math, .left, .one, .one, .right, .two, .right, .plus, .math, .left, .one, .one])
        case "cmatrix":
            // [[1,i][2,3]]→[A], then [A]², det([A]), [A]⁻¹
            keys([.second, .multiply, .second, .multiply, .one, .comma, .second, .dot, .second, .minus, .second, .multiply, .two, .comma, .three, .second, .minus, .second, .minus, .sto, .second, .inverse, .enter, .enter,
                  .second, .inverse, .enter, .square, .enter,
                  .second, .inverse, .right, .enter, .second, .inverse, .enter, .rparen, .enter,
                  .second, .inverse, .enter, .inverse, .enter])
        case "cmatrixedit":
            keys([.second, .inverse, .right, .right, .enter, .two, .enter, .two, .enter, .one, .enter, .second, .dot, .enter, .two, .enter, .three, .plus, .second, .dot, .enter])
        default: break
        }
    }
}
