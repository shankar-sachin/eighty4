import SwiftUI

/// Official TI-84 Plus CE colorways. The front face and keys stay black on every model;
/// the color is on the shell rim / back.
enum ShellColor: String, CaseIterable, Identifiable {
    case black, radicalRed, roseGold, galaxyGray, trinomialTeal, bionicBlue

    var id: String { rawValue }

    var name: String {
        switch self {
        case .black: return "Black"
        case .radicalRed: return "Radical Red"
        case .roseGold: return "Rose Gold"
        case .galaxyGray: return "Galaxy Gray"
        case .trinomialTeal: return "Trinomial Teal"
        case .bionicBlue: return "Bionic Blue"
        }
    }

    var color: Color {
        switch self {
        case .black: return Color(hex: 0x1C1C1E)
        case .radicalRed: return Color(hex: 0xC8102E)
        case .roseGold: return Color(hex: 0xC9A08A)
        case .galaxyGray: return Color(hex: 0x7A7D82)
        case .trinomialTeal: return Color(hex: 0x1E8C8A)
        case .bionicBlue: return Color(hex: 0x2A6BB5)
        }
    }

    var light: Color {
        switch self {
        case .black: return Color(hex: 0x3A3A3D)
        case .radicalRed: return Color(hex: 0xE23A52)
        case .roseGold: return Color(hex: 0xE2BFAB)
        case .galaxyGray: return Color(hex: 0x9A9DA3)
        case .trinomialTeal: return Color(hex: 0x38ABA8)
        case .bionicBlue: return Color(hex: 0x4A8AD6)
        }
    }

    var dark: Color {
        switch self {
        case .black: return Color(hex: 0x0E0E10)
        case .radicalRed: return Color(hex: 0x8C0A20)
        case .roseGold: return Color(hex: 0x9C7663)
        case .galaxyGray: return Color(hex: 0x54575C)
        case .trinomialTeal: return Color(hex: 0x136260)
        case .bionicBlue: return Color(hex: 0x1B4A82)
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
