import SwiftUI

/// Body geometry in design units: 1 unit = 0.1 mm of the real TI-84 Plus CE (86.9 × 190.5 mm).
enum Layout {
    static let bodyW: CGFloat = 869
    static let bodyH: CGFloat = 1905
    static let bodyCorner: CGFloat = 70
    static let rim: CGFloat = 22
    static let faceCorner: CGFloat = 55

    static let brandY: CGFloat = 76

    static let bezelRect = CGRect(x: 55, y: 120, width: 759, height: 570)
    // The LCD fills the glossy bezel with only a thin frame around it.
    static let lcdRect = CGRect(x: 65, y: 128, width: 739, height: 554)
    static let lcdScale: CGFloat = 739 / 320

    static let keypadLeft: CGFloat = 52.5
    static let colPitch: CGFloat = 158
    static let keyW: CGFloat = 132
    static let keyH: CGFloat = 88
    static let keyCorner: CGFloat = 14
    static let rowPitch: CGFloat = 116
    static let rowsY: CGFloat = 830

    static let row1Y: CGFloat = 728
    static let row1H: CGFloat = 64
    static let row1W: CGFloat = 118

    static let dpadCenter = CGPoint(x: 671.5, y: 932)
    static let dpadDiameter: CGFloat = 232

    /// The Evo's top row carries its own 2nd/alpha legends, so those keys are as tall as the rest.
    static func rect(row: Int, col: Int, evo: Bool = false) -> CGRect {
        let x = keypadLeft + CGFloat(col - 1) * colPitch
        if row == 1 {
            let h: CGFloat = evo ? 78 : row1H
            return CGRect(x: x + (keyW - row1W) / 2, y: row1Y + (row1H - h) / 2, width: row1W, height: h)
        }
        let y = rowsY + CGFloat(row - 2) * rowPitch
        return CGRect(x: x, y: y, width: keyW, height: keyH)
    }
}

enum Haptics {
    private static let generator = UIImpactFeedbackGenerator(style: .light)
    static func tap() {
        generator.impactOccurred(intensity: 0.7)
    }
}
