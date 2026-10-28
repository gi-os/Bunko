import SwiftUI

/// Pale wood, quietly.
struct ShelfBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(hex: "1E1B17"), Color(hex: "16130F")]
                : [Color(hex: "F2EBDD"), Color(hex: "E6DAC4")],
            startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea()
    }
}
