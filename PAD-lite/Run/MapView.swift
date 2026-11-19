import PADRoguelikeCore
import SwiftUI

/// Slay-the-Spire style map: rows from the bottom up to the boss, paths drawn between nodes.
struct MapView: View {
    let map: RunMap
    let path: [Int]
    let currentID: Int?
    let reachable: Set<Int>
    let onSelect: (Int) -> Void

    private let rowHeight: CGFloat = 84
    private let padding: CGFloat = 70

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = CGFloat(max(map.rowCount - 1, 0)) * rowHeight + padding * 2
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        Canvas { context, _ in
                            drawEdges(in: context, width: width, height: height)
                        }
                        .frame(width: width, height: height)

                        ForEach(map.nodes) { node in
                            MapNodeView(kind: node.kind, state: state(of: node))
                                .onTapGesture {
                                    if reachable.contains(node.id) { onSelect(node.id) }
                                }
                                .id(node.id)
                                .position(position(of: node, width: width, height: height))
                        }
                    }
                    .frame(width: width, height: height)
                }
                .onAppear { scroll(proxy, animated: false) }
                .onChange(of: currentID) { scroll(proxy, animated: true) }
            }
        }
    }

    // MARK: - Layout

    private func position(of node: MapNode, width: CGFloat, height: CGFloat) -> CGPoint {
        let y = height - padding - CGFloat(node.row) * rowHeight
        if node.kind == .boss { return CGPoint(x: width / 2, y: y - 12) }
        let columnWidth = (width - 56) / CGFloat(max(map.columns, 1))
        // Small fixed offsets per node so the map looks hand-drawn rather than a grid.
        let jitterX = CGFloat((node.id * 37) % 13 - 6)
        let jitterY = CGFloat((node.id * 53) % 11 - 5)
        return CGPoint(x: 28 + columnWidth * (CGFloat(node.column) + 0.5) + jitterX, y: y + jitterY)
    }

    private func state(of node: MapNode) -> MapNodeView.State {
        if node.id == currentID { return .current }
        if reachable.contains(node.id) { return .reachable }
        if path.contains(node.id) { return .visited }
        let currentRow = currentID.flatMap(map.node)?.row ?? -1
        return node.row > currentRow ? .future : .skipped
    }

    private func drawEdges(in context: GraphicsContext, width: CGFloat, height: CGFloat) {
        let walked = Set(zip(path, path.dropFirst()).map { "\($0)-\($1)" })
        for node in map.nodes {
            for nextID in node.next {
                guard let next = map.node(nextID) else { continue }
                var line = Path()
                line.move(to: position(of: node, width: width, height: height))
                line.addLine(to: position(of: next, width: width, height: height))

                let isWalked = walked.contains("\(node.id)-\(nextID)")
                let isOption = node.id == currentID && reachable.contains(nextID)
                let color: Color = isWalked ? Theme.gold : isOption ? .white.opacity(0.85) : .white.opacity(0.16)
                context.stroke(line, with: .color(color),
                               style: StrokeStyle(lineWidth: isWalked ? 4 : 2.5, lineCap: .round,
                                                  dash: isWalked ? [] : [5, 7]))
            }
        }
    }

    private func scroll(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let target = currentID ?? map.nodes(inRow: 0).first?.id else { return }
        if animated {
            withAnimation(.easeInOut(duration: 0.5)) { proxy.scrollTo(target, anchor: .center) }
        } else {
            proxy.scrollTo(target, anchor: .center)
        }
    }
}

struct MapNodeView: View {
    enum State: Equatable { case visited, current, reachable, future, skipped }

    let kind: NodeKind
    let state: State
    @SwiftUI.State private var pulse = false

    var body: some View {
        let size: CGFloat = kind == .boss ? 80 : 46
        let dimmed = state == .future || state == .skipped
        ZStack {
            Circle()
                .fill(kind.color.gradient)
                .opacity(state == .skipped ? 0.2 : dimmed ? 0.45 : 1)
            Circle()
                .strokeBorder(state == .current ? Color.white : kind.color.opacity(0.9), lineWidth: state == .current ? 4 : 2)
            Image(systemName: kind.symbol)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white.opacity(dimmed ? 0.55 : 1))
            if state == .visited {
                Circle().fill(Color.black.opacity(0.45))
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.4, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .shadow(color: state == .reachable ? kind.color : .black.opacity(0.4), radius: pulse ? 16 : 4)
        .scaleEffect(pulse ? 1.12 : 1)
        .onAppear(perform: updatePulse)
        .onChange(of: state, updatePulse)
    }

    private func updatePulse() {
        pulse = false
        guard state == .reachable else { return }
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
    }
}
