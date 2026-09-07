import SwiftUI

struct ShellPickerView: View {
    @Environment(CalculatorState.self) private var state
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 18) {
            Text("Shell Color")
                .font(.headline)
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(ShellColor.allCases) { shell in
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
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Circle().stroke(Color.white, lineWidth: state.shell == shell ? 3 : 0)
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
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
    }
}
