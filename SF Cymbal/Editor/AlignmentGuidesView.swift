import ComposableArchitecture
import SwiftUI

struct AlignmentGuidesView: View {
    let store: StoreOf<EditorFeature>
    let layout: CanvasLayout
    let canvasSize: CGSize

    var body: some View {
        ForEach(AlignmentGuide.allCases, id: \.self) { guide in
            let coordinate = switch guide {
            case .left: layout.guideFrame.minX
            case .right: layout.guideFrame.maxX
            case .top: layout.guideFrame.minY
            case .bottom: layout.guideFrame.maxY
            }
            DraggableGuideView(
                guide: guide, coordinate: coordinate, canvasSize: canvasSize,
                isActive: store.alignmentDrag?.guide == guide,
                changed: { points in store.send(.guideDragChanged(guide, points / layout.sourceScale, snapDistance: 8 / layout.sourceScale)) },
                ended: { store.send(.guideDragEnded) },
                adjusted: { amount in
                    store.send(.guideDragChanged(guide, amount))
                    store.send(.guideDragEnded)
                }
            )
        }
    }
}
