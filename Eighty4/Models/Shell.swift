import SwiftUI

/// Official colorways: six TI-84 Plus CE shells and seven TI-84 Evo shells.
enum ShellColor: String, CaseIterable, Identifiable {
    // TI-84 Plus CE
    case black, radicalRed, roseGold, galaxyGray, trinomialTeal, bionicBlue
    // TI-84 Evo
    case white, pink, mint, raspberry, silver, teal, lavender

    var id: String { rawValue }

    var model: CalcModel {
        switch self {
        case .black, .radicalRed, .roseGold, .galaxyGray, .trinomialTeal, .bionicBlue: return .ce
        case .white, .pink, .mint, .raspberry, .silver, .teal, .lavender: return .evo
        }
    }

    var name: String {
        switch self {
        case .black: return "Black"
        case .radicalRed: return "Radical Red"
        case .roseGold: return "Rose Gold"
        case .galaxyGray: return "Galaxy Gray"
        case .trinomialTeal: return "Trinomial Teal"
        case .bionicBlue: return "Bionic Blue"
        case .white: return "White"
        case .pink: return "Pink"
        case .mint: return "Mint"
        case .raspberry: return "Raspberry"
        case .silver: return "Silver"
        case .teal: return "Teal"
        case .lavender: return "Lavender"
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
        case .white: return Color(hex: 0xEDEDEA)
        case .pink: return Color(hex: 0xF2A7C3)
        case .mint: return Color(hex: 0xA9DDC8)
        case .raspberry: return Color(hex: 0xB2205A)
        case .silver: return Color(hex: 0xB9BCC2)
        case .teal: return Color(hex: 0x2F9C9A)
        case .lavender: return Color(hex: 0xC3B3E6)
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
        case .white: return Color(hex: 0xFAFAF8)
        case .pink: return Color(hex: 0xF9C6D8)
        case .mint: return Color(hex: 0xC8EEDD)
        case .raspberry: return Color(hex: 0xCF4A7E)
        case .silver: return Color(hex: 0xD6D8DC)
        case .teal: return Color(hex: 0x4FB8B5)
        case .lavender: return Color(hex: 0xDACFF2)
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
        case .white: return Color(hex: 0xCFCFCB)
        case .pink: return Color(hex: 0xD98AA6)
        case .mint: return Color(hex: 0x86C2AC)
        case .raspberry: return Color(hex: 0x86163F)
        case .silver: return Color(hex: 0x8F9298)
        case .teal: return Color(hex: 0x1F706E)
        case .lavender: return Color(hex: 0x9F8DC7)
        }
    }

    /// Light shells take dark text on the brand strip and a light front face.
    var isLight: Bool {
        switch self {
        case .white, .pink, .mint, .silver, .lavender: return true
        default: return false
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
