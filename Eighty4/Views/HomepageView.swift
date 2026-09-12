import SwiftUI

/// The app's own home screen: pick which calculator to use. Every model the app replicates gets a
/// card; the ones still to come are listed underneath so the two Eighty4 calculators never get mixed up.
struct HomepageView: View {
    @Environment(CalculatorState.self) private var state

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                VStack(spacing: 14) {
                    ForEach(CalcModel.allCases) { model in
                        Button {
                            Haptics.tap()
                            state.open(model)
                        } label: {
                            ModelCard(model: model, shell: model.defaultShell)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("homepage.\(model.rawValue)")
                    }
                }
                comingSoon
                Text("Eighty4 v\(CalculatorState.version) · not affiliated with Texas Instruments")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
        }
        .background(
            LinearGradient(colors: [Color(hex: 0x23242A), Color(hex: 0x121216)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image("Logo")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(.white.opacity(0.2), lineWidth: 1))
            Text("Eighty4")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
            Text("Choose a calculator")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var comingSoon: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COMING SOON")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.2)
            ForEach(PlannedModel.all) { m in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.brand)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                        Text(m.fullName)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    Spacer()
                    Text(m.kind)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(.white.opacity(0.05)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One calculator on the homepage: a small likeness of the body beside its name and features.
struct ModelCard: View {
    let model: CalcModel
    let shell: ShellColor

    var body: some View {
        HStack(spacing: 16) {
            MiniCalculator(model: model, shell: shell)
                .frame(width: 62, height: 116)
            VStack(alignment: .leading, spacing: 6) {
                Text(model.brand)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                Text(model.fullName + " replica")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                Text(model.tagline)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    ForEach(model.highlights.prefix(2), id: \.self) { h in
                        Text(h)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(.white.opacity(0.08)))
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.1), lineWidth: 1))
        )
    }
}

/// A thumbnail of the calculator body: shell, screen and a hint of the keypad.
struct MiniCalculator: View {
    let model: CalcModel
    let shell: ShellColor

    var body: some View {
        let evo = model == .evo
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: w * 0.13, style: .continuous)
                    .fill(LinearGradient(colors: [shell.light, shell.dark], startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(spacing: h * 0.035) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: w * 0.72, height: h * 0.3)
                        .overlay(
                            VStack(spacing: 1) {
                                Rectangle().fill(evo ? Color(hex: 0x1F6FE0) : Color(hex: 0xBFBFBF)).frame(height: 3)
                                Spacer(minLength: 0)
                            }
                        )
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(.black.opacity(0.35), lineWidth: 1))
                    VStack(spacing: h * 0.018) {
                        ForEach(0..<5, id: \.self) { row in
                            HStack(spacing: w * 0.035) {
                                ForEach(0..<5, id: \.self) { col in
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(keyColor(row: row, col: col, evo: evo))
                                        .frame(width: w * 0.12, height: h * 0.05)
                                }
                            }
                        }
                    }
                }
                .padding(.top, h * 0.08)
            }
        }
    }

    /// The Evo has black digit keys on a light face; the CE has light digits on a black face.
    private func keyColor(row: Int, col: Int, evo: Bool) -> Color {
        let digit = row >= 2 && col >= 1 && col <= 3
        if evo { return digit ? Color(hex: 0x1B1B1D) : Color.white.opacity(0.92) }
        return digit ? Color.white.opacity(0.9) : Color(hex: 0x2C2C2F)
    }
}
