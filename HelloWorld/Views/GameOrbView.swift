import SwiftUI
import GameCore

struct GameOrbView: View {
    let orb: GameOrb

    private var orbColor: Color {
        switch orb.type {
        case "fire": return .red
        case "water": return .blue
        default: return .green
        }
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(orbColor)
                .frame(width: 70, height: 70)
                .shadow(color: orbColor.opacity(0.5), radius: 6, x: 0, y: 4)

            VStack {
                Text("Lv \(orb.level)")
                    .foregroundColor(.white)
                    .font(.headline)
            }
        }
    }
}