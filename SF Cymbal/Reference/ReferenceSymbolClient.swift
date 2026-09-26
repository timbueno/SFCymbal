import AppKit
import ComposableArchitecture

struct ReferenceSymbolClient: Sendable {
    var exists: @Sendable (String) -> Bool
}

extension ReferenceSymbolClient: DependencyKey {
    static var liveValue: Self {
        Self(exists: { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil })
    }
}

extension DependencyValues {
    var referenceSymbols: ReferenceSymbolClient {
        get { self[ReferenceSymbolClient.self] }
        set { self[ReferenceSymbolClient.self] = newValue }
    }
}
