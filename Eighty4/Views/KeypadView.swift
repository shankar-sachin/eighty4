import SwiftUI

struct KeypadView: View {
    @Environment(CalculatorState.self) private var state

    static let secondBlue = Color(hex: 0x7DB4EE)
    static let alphaGreen = Color(hex: 0x8ED257)

    var body: some View {
        let evo = state.model == .evo
        ZStack(alignment: .topLeading) {
            ForEach(Keymap.keys(for: state.model)) { spec in
                let r = Layout.rect(row: spec.row, col: spec.col, evo: evo)

                // The CE prints 2nd/alpha on the faceplate above each key; the Evo prints them on the key.
                if !evo {
                    caption(for: spec)
                        .frame(width: r.width + 14, height: 24)
                        .position(x: r.midX, y: r.minY - 15)
                }

                KeyView(spec: spec, size: evo ? CGSize(width: r.width + 10, height: r.height + 12) : r.size, evo: evo) {
                    state.press(spec.id)
                }
                .accessibilityIdentifier("key.\(spec.id.rawValue)")
                .position(x: r.midX, y: r.midY)
            }

            if evo {
                EvoDPadView { state.press($0) }
                    .position(Layout.dpadCenter)
            } else {
                DPadView(evo: evo) { state.press($0) }
                    .position(Layout.dpadCenter)
            }
        }
        .frame(width: Layout.bodyW, height: Layout.bodyH)
    }

    @ViewBuilder
    private func caption(for spec: KeySpec) -> some View {
        let size: CGFloat = spec.row == 1 ? 19 : 21
        HStack(spacing: 0) {
            if let s = spec.second {
                Text(s)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(Self.secondBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 4)
            if let a = spec.alpha {
                Text(a)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(Self.alphaGreen)
                    .lineLimit(1)
            }
        }
    }
}

struct KeyView: View {
    let spec: KeySpec
    let size: CGSize
    var evo = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            ZStack(alignment: .topLeading) {
                if evo, spec.second != nil || spec.alpha != nil {
                    // Evo: 2nd legend top-left, alpha legend top-right, printed on the key.
                    HStack(alignment: .top, spacing: 0) {
                        if let s = spec.second {
                            Text(s)
                                .font(.system(size: spec.row == 1 ? 13 : 15, weight: .bold))
                                .foregroundStyle(KeypadView.secondBlue)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        Spacer(minLength: 2)
                        if let a = spec.alpha {
                            Text(a)
                                .font(.system(size: spec.row == 1 ? 13 : 15, weight: .bold))
                                .foregroundStyle(KeypadView.alphaGreen)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, spec.row == 1 ? 6 : 8)
                    .padding(.top, spec.row == 1 ? 3 : 5)
                    .frame(width: size.width)
                }
                legend
                    .frame(width: size.width, height: size.height)
                    .offset(y: evo ? (spec.row == 1 ? 8 : 7) : 0)
            }
            .frame(width: size.width, height: size.height)
            .contentShape(RoundedRectangle(cornerRadius: Layout.keyCorner))
        }
        .buttonStyle(KeyButtonStyle(style: spec.style, evo: evo))
    }

    @ViewBuilder
    private var legend: some View {
        let fg: Color = spec.style == .white ? Color(hex: 0x1A1A1A) : .white
        if evo, spec.id == .on {
            HStack(spacing: 6) {
                Image(systemName: "house.fill").font(.system(size: 24, weight: .semibold))
                Text("on").font(.system(size: 26, weight: .medium))
            }
            .foregroundStyle(fg)
        } else if evo, spec.id == .expTemplate {
            HStack(alignment: .top, spacing: 1) {
                Text("x").font(.system(size: 32, weight: .medium))
                RoundedRectangle(cornerRadius: 2).stroke(fg, lineWidth: 2).frame(width: 14, height: 14).offset(y: -2)
            }
            .foregroundStyle(fg)
        } else if evo, spec.id == .fraction {
            VStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 2).stroke(fg, lineWidth: 2).frame(width: 14, height: 12)
                Rectangle().fill(fg).frame(width: 26, height: 2.5)
                RoundedRectangle(cornerRadius: 2).stroke(fg, lineWidth: 2).frame(width: 14, height: 12)
            }
        } else {
            Text(spec.primary)
                .font(.system(size: spec.legendSize, weight: .medium))
                .foregroundStyle(fg)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

struct KeyButtonStyle: ButtonStyle {
    let style: KeyStyle
    var evo = false

    private var colors: (top: Color, bottom: Color, stroke: Color) {
        switch style {
        case .dark: return evo ? (Color(hex: 0x3A3A3C), Color(hex: 0x1B1B1D), Color(hex: 0x0A0A0B)) : (Color(hex: 0x3B3B3E), Color(hex: 0x1E1E20), Color(hex: 0x070708))
        case .white: return evo ? (Color(hex: 0xFFFFFF), Color(hex: 0xF2F2F0), Color(hex: 0xD2D2CE)) : (Color(hex: 0xFBFBF9), Color(hex: 0xE2E2DE), Color(hex: 0xA9A9A5))
        case .blue: return (Color(hex: 0x62A9EA), Color(hex: 0x3676BF), Color(hex: 0x1F4E86))
        case .green: return (Color(hex: 0x82C94E), Color(hex: 0x54962E), Color(hex: 0x36641C))
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let c = colors
        let corner: CGFloat = evo ? Layout.keyCorner + 6 : Layout.keyCorner
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(LinearGradient(colors: [c.top, c.bottom], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .stroke(c.stroke, lineWidth: 1.5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .inset(by: 2)
                            .stroke(Color.white.opacity(style == .white ? 0.6 : 0.10), lineWidth: 1)
                            .mask(
                                LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center)
                            )
                    )
            )
            .shadow(color: .black.opacity(evo ? 0.35 : 0.65), radius: 2.5, y: configuration.isPressed ? 1 : 4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.easeOut(duration: 0.07), value: configuration.isPressed)
    }
}

struct DPadView: View {
    var evo = false
    let press: (KeyID) -> Void

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: evo ? [Color(hex: 0x4A4A4E), Color(hex: 0x27272A)] : [Color(hex: 0x3A3A3D), Color(hex: 0x1B1B1D)],
                        center: .center, startRadius: 20, endRadius: Layout.dpadDiameter / 2
                    )
                )
                .overlay(Circle().stroke(Color(hex: 0x070708), lineWidth: 2))
                .shadow(color: .black.opacity(evo ? 0.35 : 0.65), radius: 3, y: 4)

            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1.5)
                .padding(48)

            Circle()
                .fill(Color(hex: 0x151516))
                .frame(width: 70, height: 70)

            // Each arrow owns a full quadrant wedge of the disc, so there are no dead zones.
            arrow(.up, "▲", start: 225, end: 315, offset: CGSize(width: 0, height: -74))
            arrow(.right, "▶", start: -45, end: 45, offset: CGSize(width: 74, height: 0))
            arrow(.down, "▼", start: 45, end: 135, offset: CGSize(width: 0, height: 74))
            arrow(.left, "◀", start: 135, end: 225, offset: CGSize(width: -74, height: 0))
        }
        .frame(width: Layout.dpadDiameter, height: Layout.dpadDiameter)
    }

    private func arrow(_ key: KeyID, _ glyph: String, start: Double, end: Double, offset: CGSize) -> some View {
        Button {
            Haptics.tap()
            press(key)
        } label: {
            ZStack {
                Color.clear
                Text(glyph)
                    .font(.system(size: 30))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .offset(offset)
            }
            .frame(width: Layout.dpadDiameter, height: Layout.dpadDiameter)
            .contentShape(Wedge(startDegrees: start, endDegrees: end))
        }
        .buttonStyle(DPadArrowStyle())
        .accessibilityIdentifier("dpad.\(key.rawValue)")
    }
}

/// A pie-slice of the enclosing circle, measured clockwise from the +x axis (SwiftUI coordinates).
struct Wedge: Shape {
    let startDegrees: Double
    let endDegrees: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        p.move(to: c)
        p.addArc(center: c, radius: rect.width / 2, startAngle: .degrees(startDegrees), endAngle: .degrees(endDegrees), clockwise: false)
        p.closeSubpath()
        return p
    }
}

struct DPadArrowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : 1)
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.07), value: configuration.isPressed)
    }
}

/// TI-84 Evo arrow cluster: four separate keys in a diamond. 2nd+◀/▶ jump to the ends of a line
/// and 2nd+▲/▼ brighten and dim the screen, so each key carries a small legend of its own.
struct EvoDPadView: View {
    let press: (KeyID) -> Void

    private let keyW: CGFloat = 104
    private let keyH: CGFloat = 74
    private let gap: CGFloat = 6

    var body: some View {
        ZStack {
            arrow(.up, "▲", legend: "☀", offset: CGSize(width: 0, height: -(keyH + gap) / 2 - 12))
            arrow(.down, "▼", legend: "☀", offset: CGSize(width: 0, height: (keyH + gap) / 2 + 12))
            arrow(.left, "◀", legend: "|◂", offset: CGSize(width: -(keyW + gap) / 2 - 10, height: 0))
            arrow(.right, "▶", legend: "▸|", offset: CGSize(width: (keyW + gap) / 2 + 10, height: 0))
        }
        .frame(width: Layout.dpadDiameter + 30, height: Layout.dpadDiameter + 10)
    }

    private func arrow(_ key: KeyID, _ glyph: String, legend: String, offset: CGSize) -> some View {
        let horizontal = key == .left || key == .right
        return Button {
            Haptics.tap()
            press(key)
        } label: {
            ZStack {
                Text(legend)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(KeypadView.secondBlue)
                    .offset(horizontal ? CGSize(width: 0, height: -1) : CGSize(width: 0, height: key == .up ? -1 : 1))
                Text(glyph)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(horizontal ? CGSize(width: key == .left ? -30 : 30, height: 0)
                                       : CGSize(width: 0, height: key == .up ? -20 : 20))
            }
            .frame(width: horizontal ? keyW : keyW, height: horizontal ? keyH : keyH)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(EvoArrowStyle())
        .offset(offset)
        .accessibilityIdentifier("dpad.\(key.rawValue)")
    }
}

struct EvoArrowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0x3A3A3C), Color(hex: 0x1B1B1D)], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color(hex: 0x0A0A0B), lineWidth: 1.5))
            )
            .shadow(color: .black.opacity(0.35), radius: 2.5, y: configuration.isPressed ? 1 : 4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.07), value: configuration.isPressed)
    }
}
