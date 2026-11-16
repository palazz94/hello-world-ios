import SwiftUI

struct ContentView: View {
    // iPhone Duo: outer display is compact width, inner display is regular width.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack {
            Text(horizontalSizeClass == .regular
                 ? "Eros è gayo"
                 : "hey, c'è una sorpresa per te! Apri per scoprirla")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
