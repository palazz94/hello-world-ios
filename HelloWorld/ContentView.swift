import SwiftUI

struct ContentView: View {
    // iPhone Duo: outer display is compact width, inner display is regular width.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var hinge: DeviceHinge?

    var body: some View {
        VStack(spacing: 16) {
            Text(horizontalSizeClass == .regular // .compact se schermo esterno, .regular se schermo interno
                 ? "Eros è gayo"
                 : "hey, c'è una sorpresa per te! Apri per scoprirla")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            if let hinge {
                Text("Hinge: \(hinge.angle.degrees, specifier: "%.1f")°")
                    .font(.title2)
                    .monospacedDigit()
            } else {
                Text("Hinge non disponibile")
                    .font(.title2)
            }
        }
        .padding()
        .onHingeChange { _, newContext in
            hinge = newContext.hinge
        }
    }
}

#Preview {
    ContentView()
}
