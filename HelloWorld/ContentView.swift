import SwiftUI
import os
import GameOrbView

private let logger = Logger(subsystem: "HelloWorld", category: "ContentView")

struct ContentView: View {
    // iPhone Duo: outer display is compact width, inner display is regular width.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var hinge: DeviceHinge?
    @State private var score: Int = 0
    @State private var playerOrbs: [GameOrb] = [GameOrb(type: "fire", level: 1), GameOrb(type: "water", level: 1), GameOrb(type: "nature", level: 1)]

    var body: some View {
        let _ = logger.notice("ContentView body called")
        
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
            Button("Increment Score") {
                playerOrbs[0].level += 1
            }
            .buttonStyle(.borderedProminent)
            Button("Reset Score") {
                playerOrbs[0].level = 1
            }
            .buttonStyle(.borderedProminent)
        }

        HStack(spacing: 16) {
            ForEach(playerOrbs.indices, id: \.self) { index in
                GameOrbView(orb: playerOrbs[index])
            }
        }
        .padding(.vertical, 8)

        .padding()
        .onHingeChange { _, newContext in
            hinge = newContext.hinge
        }
    }
}

#Preview {
    ContentView()
}
