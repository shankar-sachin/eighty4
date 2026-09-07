import SwiftUI

/// Vernier EasyData: sensor front-end. Without a sensor it behaves like the real app
/// (setup lists the supported probes, Start waits for a device).
final class VernierApp: Game {
    let title = "EASYDATA"
    private(set) var wantsExit = false
    let handlesClear = true

    private enum Mode { case main, setup, waiting, graph }
    private var mode: Mode = .main
    private var setupRow = 0
    private var startTime: TimeInterval? = nil
    private var now: TimeInterval = 0
    private let sensors = ["Temperature (°C)", "Light (lux)", "Motion (m)", "Voltage (V)", "pH", "Force (N)"]

    func update(now: TimeInterval) { self.now = now }
    func press(_ key: KeyID) {}

    func handle(_ key: KeyID, _ action: KeyAction) {
        switch mode {
        case .main:
            switch AppUI.fkey(key) {
            case 1: mode = .main
            case 2: mode = .setup
            case 3: mode = .waiting; startTime = now
            case 4: mode = .graph
            case 5: wantsExit = true
            default: if action == .clear { wantsExit = true }
            }
        case .setup:
            switch action {
            case .up: setupRow = (setupRow + sensors.count - 1) % sensors.count
            case .down: setupRow = (setupRow + 1) % sensors.count
            case .enter, .clear: mode = .main
            default: if AppUI.fkey(key) == 5 { mode = .main }
            }
        case .waiting, .graph:
            if action == .clear || action == .enter || AppUI.fkey(key) == 5 { mode = .main }
        }
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        AppUI.text(&ctx, "Vernier EasyData", row: 0, col: 0, inverted: true)
        switch mode {
        case .main:
            AppUI.text(&ctx, "Mode: Meter", row: 1, col: 0)
            AppUI.text(&ctx, sensors[setupRow], row: 2, col: 0)
            AppUI.centered(&ctx, "---.--", row: 4)
            AppUI.text(&ctx, "No sensor detected.", row: 6, col: 0)
            AppUI.text(&ctx, "Plug a Vernier EasyLink or", row: 7, col: 0)
            AppUI.text(&ctx, "EasyTemp into the USB port.", row: 8, col: 0)
            AppUI.softkeys(&ctx, ["File", "Setup", "Start", "Graph", "Quit"], size: size)
        case .setup:
            AppUI.text(&ctx, "SENSOR SETUP", row: 1, col: 0)
            for (i, s) in sensors.enumerated() {
                AppUI.text(&ctx, "\(i + 1)", row: 2 + i, col: 0, inverted: i == setupRow)
                AppUI.text(&ctx, ":" + s, row: 2 + i, col: 1)
            }
            AppUI.softkeys(&ctx, ["", "", "", "", "OK"], size: size)
        case .waiting:
            let secs = Int(now - (startTime ?? now))
            AppUI.text(&ctx, "Collecting…  \(secs)s", row: 2, col: 0)
            AppUI.text(&ctx, "Waiting for sensor data.", row: 4, col: 0)
            AppUI.text(&ctx, "No device on the USB port.", row: 5, col: 0)
            AppUI.softkeys(&ctx, ["", "", "", "", "Stop"], size: size)
        case .graph:
            var axes = Path()
            axes.move(to: CGPoint(x: 30, y: 30)); axes.addLine(to: CGPoint(x: 30, y: 180)); axes.addLine(to: CGPoint(x: 300, y: 180))
            ctx.stroke(axes, with: .color(.black), lineWidth: 1)
            ctx.drawText("No data collected", at: CGPoint(x: 160, y: 100), size: 11, weight: .regular, color: .black, anchor: .center)
            AppUI.softkeys(&ctx, ["Main", "", "", "", "Quit"], size: size)
        }
    }
}
