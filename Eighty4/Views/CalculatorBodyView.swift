import SwiftUI

struct CalculatorBodyView: View {
    @Environment(CalculatorState.self) private var state

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Colored shell rim.
            RoundedRectangle(cornerRadius: Layout.bodyCorner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [state.shell.light, state.shell.color, state.shell.dark],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.55), radius: 30, y: 18)

            // Black front face.
            RoundedRectangle(cornerRadius: Layout.faceCorner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x1A1A1B), Color(hex: 0x111112)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .padding(Layout.rim)

            // USB-C port + charge LED on the right edge.
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.75))
                .frame(width: 12, height: 64)
                .position(x: Layout.bodyW - 7, y: 560)
            Circle()
                .fill(Color(hex: 0xFF8A00).opacity(0.9))
                .frame(width: 8, height: 8)
                .position(x: Layout.bodyW - 9, y: 505)

            BrandStripView()
                .frame(width: Layout.bodyW - 2 * 68, height: 60)
                .position(x: Layout.bodyW / 2, y: Layout.brandY)

            // Glossy screen bezel.
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x0D0D0E), Color(hex: 0x050506)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.07), location: 0),
                                    .init(color: .white.opacity(0.0), location: 0.45),
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1.5)
                )
                .frame(width: Layout.bezelRect.width, height: Layout.bezelRect.height)
                .position(x: Layout.bezelRect.midX, y: Layout.bezelRect.midY)

            // LCD (rendered at 320×240 and scaled up).
            LCDView()
                .scaleEffect(Layout.lcdScale)
                .frame(width: Layout.lcdRect.width, height: Layout.lcdRect.height)
                .overlay(
                    Rectangle().stroke(Color(hex: 0x2A2A2C), lineWidth: 2)
                )
                .position(x: Layout.lcdRect.midX, y: Layout.lcdRect.midY)

            KeypadView()
        }
        .frame(width: Layout.bodyW, height: Layout.bodyH)
    }
}

struct BrandStripView: View {
    @Environment(CalculatorState.self) private var state

    var body: some View {
        HStack(alignment: .center) {
            Text("Eighty4")
                .font(.system(size: 36, weight: .semibold, design: .default))
                .foregroundStyle(Color.white.opacity(0.92))
                .tracking(1)
            Spacer()
            Image("Logo")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.4) {
            Haptics.tap()
            state.showShellPicker = true
        }
    }
}
