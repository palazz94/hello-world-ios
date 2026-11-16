import SwiftUI
import UIKit

struct ContentView: View {
    @State private var isExternalScreen = false

    var body: some View {
        VStack {
            Text(isExternalScreen
                 ? "hey, c'è una sorpresa per te! Apri per scoprirla"
                 : "Eros è gayo")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(ScreenRoleReader { isExternalScreen = $0 })
    }
}

// Reports whether the hosting window belongs to the external display scene.
struct ScreenRoleReader: UIViewRepresentable {
    let onChange: (Bool) -> Void

    func makeUIView(context: Context) -> RoleView {
        RoleView(onChange: onChange)
    }

    func updateUIView(_ uiView: RoleView, context: Context) {}
}

final class RoleView: UIView {
    private let onChange: (Bool) -> Void

    init(onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        let isExternal = window?.windowScene?.session.role == .windowExternalDisplayNonInteractive
        DispatchQueue.main.async { self.onChange(isExternal) }
    }
}

#Preview {
    ContentView()
}
