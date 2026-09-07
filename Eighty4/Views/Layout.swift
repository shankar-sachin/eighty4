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
    static let lcdRect = CGRect(x: 149.5, y: 190, width: 570, height: 430)
    static let lcdScale: CGFloat = 570 / 320

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

    static func rect(row: Int, col: Int) -> CGRect {
        let x = keypadLeft + CGFloat(col - 1) * colPitch
        if row == 1 {
            return CGRect(x: x + (keyW - row1W) / 2, y: row1Y, width: row1W, height: row1H)
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
