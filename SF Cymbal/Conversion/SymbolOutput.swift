import Foundation
import SwiftDraw

struct SymbolOutput: Equatable, Sendable {
    var data: Data
    var previews: [String: SVG]
    var pathCount: Int
    var alignment: [String: AlignmentGeometry] = [:]
}
