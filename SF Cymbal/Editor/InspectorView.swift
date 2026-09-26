import ComposableArchitecture
import SwiftUI

struct InspectorView: View {
    @Bindable var store: StoreOf<EditorFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Alignment", systemImage: "viewfinder").font(.headline)
                        Spacer()
                        Button("Reset alignment", systemImage: "arrow.counterclockwise") {
                            store.send(.alignmentResetButtonTapped)
                        }
                        .labelStyle(.iconOnly).buttonStyle(.borderless)
                        .help("Reset all alignment values to zero")
                    }
                    Toggle("Fit guides to artwork", isOn: $store.settings.automaticAlignment.sending(\.automaticAlignmentToggled))
                        .toggleStyle(.checkbox)
                    Text("Zero is the visible artwork edge. Positive values move guides inward; negative values add space.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        InsetField(title: "Left", value: $store.settings.left)
                        InsetField(title: "Right", value: $store.settings.right)
                    }
                    .disabled(store.settings.automaticAlignment)
                    HStack(spacing: 12) {
                        InsetField(title: "Cap", value: $store.settings.top)
                        InsetField(title: "Baseline", value: $store.settings.bottom)
                    }
                    .padding(.top, 2)
                    .disabled(store.settings.automaticAlignment)
                }
                .disabled(store.source == nil)

                Divider()
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Stroke weights", systemImage: "slider.horizontal.3").font(.headline)
                        Spacer()
                        Button("Reset stroke weights", systemImage: "arrow.counterclockwise") {
                            store.send(.symbolSettingsResetButtonTapped)
                        }
                        .labelStyle(.iconOnly).buttonStyle(.borderless)
                        .help("Reset stroke weight generation and scales")
                    }
                    Toggle("Generate stroke weights", isOn: $store.settings.generateWeights)
                        .toggleStyle(.checkbox)
                    HStack {
                        Text("Ultralight scale").foregroundStyle(.secondary)
                        Spacer()
                        TextField("Ultralight multiplier", value: $store.settings.minimumStroke, format: .number)
                            .frame(width: 64).multilineTextAlignment(.trailing)
                    }
                    .disabled(!store.settings.generateWeights)
                    HStack {
                        Text("Black scale").foregroundStyle(.secondary)
                        Spacer()
                        TextField("Black multiplier", value: $store.settings.maximumStroke, format: .number)
                            .frame(width: 64).multilineTextAlignment(.trailing)
                    }
                    .disabled(!store.settings.generateWeights)
                    Text("Weight generation scales strokes. Filled paths keep their original weight.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .textFieldStyle(.roundedBorder)
                .disabled(store.source == nil)
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Link(destination: URL(string: "https://github.com/swhitty/SwiftDraw")!) {
                HStack(spacing: 4) {
                    Text("Powered by SwiftDraw")
                    Image(systemName: "arrow.up.right")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .tint(.secondary)
            .foregroundStyle(.secondary)
            .help("Open the SwiftDraw project on GitHub")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(.background.secondary)
    }
}
