import ComposableArchitecture
import SwiftUI

struct ReferencePickerView: View {
    @Bindable var store: StoreOf<ReferenceFeature>

    @AppStorage("preferredReferenceKind") private var preferredKind = ReferenceKind.letter.rawValue
    @AppStorage("preferredReferenceSymbol") private var preferredSymbol = "star"

    private let suggestions = ["star", "heart.fill", "circle", "square", "person.fill", "bolt.fill", "house", "arrow.right"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Canvas reference").font(.headline)
            Picker("Reference", selection: $store.kind.sending(\.kindChanged)) {
                ForEach(ReferenceKind.allCases, id: \.self) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented).labelsHidden()
            if store.kind == .symbol {
                HStack(spacing: 12) {
                    Image(systemName: store.symbolName)
                        .font(.system(size: 32))
                        .frame(width: 48, height: 48)
                        .foregroundStyle(.cyan)
                        .background(.cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel(store.symbolName)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("SF Symbol name").font(.caption).foregroundStyle(.secondary)
                        TextField("e.g. square.and.arrow.up", text: $store.draftName.sending(\.symbolNameChanged))
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .accessibilityLabel("SF Symbol name")
                    }
                }
                if let error = store.error {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Showing: \(store.symbolName)").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Enter any system symbol name available on this Mac.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { name in
                        Button { store.send(.suggestedSymbolTapped(name)) } label: {
                            Image(systemName: name).frame(width: 24, height: 24)
                        }
                        .buttonStyle(.borderless)
                        .help(name).accessibilityLabel("Use \(name)")
                    }
                }
            }
            Button("Use as Default for New Documents") {
                preferredKind = store.kind.rawValue
                preferredSymbol = store.symbolName
            }
            .disabled(store.error != nil || (preferredKind == store.kind.rawValue && preferredSymbol == store.symbolName))
            Text("The reference follows your guides. It isn’t included in the exported SVG.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 310, alignment: .leading)
        .padding(20)
    }
}
