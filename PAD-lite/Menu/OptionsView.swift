import SwiftUI

struct OptionsView: View {
    @Environment(GameProgress.self) private var progress

    var body: some View {
        @Bindable var progress = progress
        Form {
            Section("Gioco") {
                Stepper(value: $progress.settings.moveDuration, in: 3...10, step: 1) {
                    Text("Tempo per mossa: \(Int(progress.settings.moveDuration)) s")
                }
                Toggle("Vibrazione", isOn: $progress.settings.hapticsEnabled)
            }
        }
        .navigationTitle("Opzioni")
    }
}
