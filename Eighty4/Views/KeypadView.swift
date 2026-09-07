import SwiftUI

struct KeypadView: View {
    @Environment(CalculatorState.self) private var state

    private static let secondBlue = Color(hex: 0x7DB4EE)
    private static let alphaGreen = Color(hex: 0x8ED257)

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Keymap.keys) { spec in
                let r = Layout.rect(row: spec.row, col: spec.col)

                caption(for: spec)
                    .frame(width: r.width + 14, height: 24)
                    .position(x: r.midX, y: r.minY - 15)

                KeyView(spec: spec, size: r.size) {
                    state.press(spec.id)
                }
                .accessibilityIdentifier("key.\(spec.id.rawValue)")
                .position(x: r.midX, y: r.midY)
            }

            DPadView { state.press($0) }
                .position(Layout.dpadCenter)
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
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(spec.primary)
                .font(.system(size: spec.legendSize, weight: spec.style == .white ? .medium : .medium))
                .foregroundStyle(spec.style == .white ? Color(hex: 0x111111) : Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: size.width, height: size.height)
                .contentShape(RoundedRectangle(cornerRadius: Layout.keyCorner))
        }
        .buttonStyle(KeyButtonStyle(style: spec.style))
    }
}

struct KeyButtonStyle: ButtonStyle {
    let style: KeyStyle

    private var colors: (top: Color, bottom: Color, stroke: Color) {
        switch style {
        case .dark: return (Color(hex: 0x3B3B3E), Color(hex: 0x1E1E20), Color(hex: 0x070708))
        case .white: return (Color(hex: 0xFBFBF9), Color(hex: 0xE2E2DE), Color(hex: 0xA9A9A5))
        case .blue: return (Color(hex: 0x62A9EA), Color(hex: 0x3676BF), Color(hex: 0x1F4E86))
        case .green: return (Color(hex: 0x82C94E), Color(hex: 0x54962E), Color(hex: 0x36641C))
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let c = colors
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: Layout.keyCorner, style: .continuous)
                    .fill(LinearGradient(colors: [c.top, c.bottom], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.keyCorner, style: .continuous)
                            .stroke(c.stroke, lineWidth: 1.5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.keyCorner, style: .continuous)
                            .inset(by: 2)
                            .stroke(Color.white.opacity(style == .white ? 0.6 : 0.10), lineWidth: 1)
                            .mask(
                                LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center)
                            )
                    )
            )
            .shadow(color: .black.opacity(0.65), radius: 2.5, y: configuration.isPressed ? 1 : 4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.easeOut(duration: 0.07), value: configuration.isPressed)
    }
}

struct DPadView: View {
    let press: (KeyID) -> Void

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0x3A3A3D), Color(hex: 0x1B1B1D)],
                        center: .center, startRadius: 20, endRadius: Layout.dpadDiameter / 2
                    )
                )
                .overlay(Circle().stroke(Color(hex: 0x070708), lineWidth: 2))
                .shadow(color: .black.opacity(0.65), radius: 3, y: 4)

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
