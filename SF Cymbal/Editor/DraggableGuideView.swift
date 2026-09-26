import AppKit
import SwiftUI

struct DraggableGuideView: View {
    let guide: AlignmentGuide
    let coordinate: Double
    let canvasSize: CGSize
    let isActive: Bool
    var changed: (Double) -> Void
    var ended: () -> Void
    var adjusted: (Double) -> Void
    @State private var isHovering = false

    var body: some View {
        ZStack {
            Rectangle().fill(.cyan.opacity(isActive || isHovering ? 1 : 0.65))
                .frame(width: guide.isVertical ? (isActive ? 2 : 1) : canvasSize.width,
                       height: guide.isVertical ? canvasSize.height : (isActive ? 2 : 1))
            if isHovering || isActive {
                Capsule().fill(.cyan)
                    .frame(width: guide.isVertical ? 5 : 28, height: guide.isVertical ? 28 : 5)
            }
        }
        .frame(width: guide.isVertical ? 18 : canvasSize.width,
               height: guide.isVertical ? canvasSize.height : 18)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("symbolCanvas"))
                .onChanged { value in changed(guide.isVertical ? value.translation.width : value.translation.height) }
                .onEnded { _ in ended() }
        )
        .onHover { hovering in
            isHovering = hovering
            if hovering { (guide.isVertical ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).set() }
            else { NSCursor.arrow.set() }
        }
        .position(x: guide.isVertical ? coordinate : canvasSize.width / 2,
                  y: guide.isVertical ? canvasSize.height / 2 : coordinate)
        .overlay(alignment: .topLeading) {
            if !guide.isVertical {
                Text(guide.title.uppercased())
                    .font(.system(size: 9, weight: .medium)).foregroundStyle(.cyan)
                    .fixedSize()
                    .position(x: 50, y: coordinate - 12)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(guide.title)
        .accessibilityHint("Drag to adjust alignment. Turns off Fit guides to artwork.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: adjusted(1)
            case .decrement: adjusted(-1)
            @unknown default: break
            }
        }
    }
}
