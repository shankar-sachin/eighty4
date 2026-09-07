import SwiftUI

@main
struct Eighty4App: App {
    @State private var state = Eighty4App.makeState()

    /// Launch arguments used for screenshot verification:
    ///   -demo            scripts a few key presses into the home screen
    ///   -shell <name>    forces a shell colorway (e.g. radicalRed)
    private static func makeState() -> CalculatorState {
        let s = CalculatorState()
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-shell"), i + 1 < args.count, let c = ShellColor(rawValue: args[i + 1]) {
            s.shell = c
        }
        if args.contains("-demo") {
            let script: [KeyID] = [
                .two, .plus, .three, .multiply, .four, .enter,
                .second, .square, .two, .rparen, .enter,
                .one, .divide, .three, .enter,
                .second, .negate, .power, .two, .enter,
                .sin, .second, .power, .divide, .two, .second,
            ]
            script.forEach { s.press($0) }
        }
        return s
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(state)
                .preferredColorScheme(.dark)
        }
    }
}
