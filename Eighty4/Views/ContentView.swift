import SwiftUI

struct ContentView: View {
    @Environment(CalculatorState.self) private var state

    var body: some View {
        @Bindable var state = state
        GeometryReader { geo in
            let scale = min(geo.size.width / Layout.bodyW, geo.size.height / Layout.bodyH) * 0.985
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x2E2E31), Color(hex: 0x1B1B1D)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                HardwareKeyboardView { state.pressHardware($0) }
                    .frame(width: 0, height: 0)

                CalculatorBodyView()
                    .frame(width: Layout.bodyW, height: Layout.bodyH)
                    .scaleEffect(scale)
                    .frame(width: Layout.bodyW * scale, height: Layout.bodyH * scale)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Shell color picker button (also reachable by long-pressing the wordmark).
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            Haptics.tap()
                            state.showShellPicker = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [state.shell.light, state.shell.dark], startPoint: .topLeading, endPoint: .bottomTrailing))
                                Circle().stroke(Color.white.opacity(0.6), lineWidth: 1)
                                Image(systemName: "paintpalette.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 32, height: 32)
                        }
                        .accessibilityIdentifier("shellPicker")
                        .padding(.trailing, 14)
                        .padding(.top, 2)
                    }
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $state.showShellPicker) {
            ShellPickerView()
        }
    }
}
