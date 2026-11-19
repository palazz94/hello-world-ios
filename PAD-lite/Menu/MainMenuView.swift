import PADRoguelikeCore
import SwiftUI

struct MainMenuView: View {
    let onPlay: (Level) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                Text("PAD-lite")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .italic()
                Spacer()
                menuLink("Gioca", systemImage: "play.fill") { LevelSelectView(onPlay: onPlay) }
                menuLink("Talenti", systemImage: "star.fill") { TalentsView() }
                menuLink("Opzioni", systemImage: "gearshape.fill") { OptionsView() }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.07, green: 0.06, blue: 0.12))
        }
        .preferredColorScheme(.dark)
    }

    private func menuLink<Destination: View>(_ title: String, systemImage: String,
                                             @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
            Label(title, systemImage: systemImage)
                .font(.title3.bold())
                .frame(maxWidth: 240)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}
