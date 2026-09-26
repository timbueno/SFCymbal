import ComposableArchitecture
import Foundation

struct SymbolClient: Sendable {
    var convert: @Sendable (Data, SymbolSettings) async throws -> SymbolOutput
    var prepare: @Sendable (Data) async throws -> ImportedArtwork = { try await SymbolConverter.shared.prepare(data: $0) }
    var read: @Sendable (URL) async throws -> Data
}

extension SymbolClient: DependencyKey {
    static var liveValue: Self { Self(
        convert: { try await SymbolConverter.shared.convert(data: $0, settings: $1) },
        read: { try await SymbolConverter.shared.read(url: $0) }
    ) }
}

extension DependencyValues {
    var symbolClient: SymbolClient {
        get { self[SymbolClient.self] }
        set { self[SymbolClient.self] = newValue }
    }
}
