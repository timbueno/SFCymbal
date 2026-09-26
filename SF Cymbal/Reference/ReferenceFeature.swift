import ComposableArchitecture
import Foundation

@Reducer
struct ReferenceFeature {
    @ObservableState
    struct State: Equatable {
        var draftName = "star"
        var error: String?
        var kind = ReferenceKind.letter
        var symbolName = "star"
    }

    enum Action {
        case kindChanged(ReferenceKind)
        case symbolNameChanged(String)
        case suggestedSymbolTapped(String)
    }

    @Dependency(\.referenceSymbols) var symbols

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .kindChanged(let kind):
                state.kind = kind
            case .symbolNameChanged(let input):
                state.draftName = input
                validate(&state)
            case .suggestedSymbolTapped(let name):
                state.draftName = name
                state.kind = .symbol
                validate(&state)
            }
            return .none
        }
    }

    private func validate(_ state: inout State) {
        let name = state.draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            state.error = "Enter an SF Symbol name."
            return
        }
        guard symbols.exists(name) else {
            state.error = "This symbol isn’t available on this Mac. Check its name in Apple’s SF Symbols app."
            return
        }
        state.symbolName = name
        state.error = nil
    }
}
