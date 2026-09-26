import SwiftUI

struct InsetField: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, value: $value, format: .number.precision(.fractionLength(0...3)))
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("\(title) inset")
        }
    }
}
