import SwiftUI

/// Model (TI-84 Plus CE / TI-84 Evo) and shell colorway picker.
struct ShellPickerView: View {
    @Environment(CalculatorState.self) private var state
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 18) {
            Text("Calculator")
                .font(.headline)
            Picker("Model", selection: $state.model) {
                ForEach(CalcModel.allCases) { m in
                    Text(m.brand).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("modelPicker")
            Text("Shell Color")
                .font(.headline)
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(state.model.shells) { shell in
                    Button {
                        state.shell = shell
                        Haptics.tap()
                        dismiss()
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(
                                    LinearGradient(colors: [shell.light, shell.dark],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Circle().stroke(Color.white, lineWidth: state.shell == shell ? 3 : 0)
                                )
                                .overlay(
                                    Circle().stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                            Text(shell.name)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(24)
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
    }
}
