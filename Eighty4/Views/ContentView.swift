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

                CalculatorBodyView()
                    .frame(width: Layout.bodyW, height: Layout.bodyH)
                    .scaleEffect(scale)
                    .frame(width: Layout.bodyW * scale, height: Layout.bodyH * scale)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $state.showShellPicker) {
            ShellPickerView()
        }
    }
}
