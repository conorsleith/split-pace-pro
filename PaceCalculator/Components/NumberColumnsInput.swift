import SwiftUI

/// One numeric column of a multi-column input, e.g. minutes 0...59.
struct NumberColumn: Hashable {
    var range: ClosedRange<Int>
    /// Zero-pad to this many digits.
    var digits: Int = 1
    /// Fixed text shown after the column, e.g. ":" or ".".
    var separator: String? = nil
    /// Wheel wraps around (59 → 00), like the system timer picker.
    var wraps = false
    /// Text shown for each value instead of the number, e.g. ["mi", "km"].
    var labels: [String]? = nil
    var accessibilityLabel: String

    /// Wider column for two-digit numbers and text labels.
    var isWide: Bool { digits > 1 || labels != nil }

    func text(_ value: Int) -> String {
        if let labels { return labels[value - range.lowerBound] }
        let s = String(value)
        return String(repeating: "0", count: max(0, digits - s.count)) + s
    }
}

/// Wheels on iOS, number fields on macOS.
struct NumberColumnsInput: View {
    var columns: [NumberColumn]
    @Binding var values: [Int]

    var body: some View {
        #if os(iOS)
        WheelPicker(columns: columns, values: $values)
            .frame(height: 160)
        #else
        HStack(spacing: 4) {
            ForEach(columns.indices, id: \.self) { i in
                NumberField(column: columns[i], value: binding(i))
                if let separator = columns[i].separator {
                    Text(separator).font(.title2.monospacedDigit())
                }
            }
        }
        #endif
    }

    private func binding(_ i: Int) -> Binding<Int> {
        Binding(
            get: { values[i] },
            set: { values[i] = min(max($0, columns[i].range.lowerBound), columns[i].range.upperBound) }
        )
    }
}

#if os(macOS)
private struct NumberField: View {
    var column: NumberColumn
    @Binding var value: Int

    var body: some View {
        TextField(column.accessibilityLabel, value: $value, format: .number.grouping(.never))
            .labelsHidden()
            .multilineTextAlignment(.center)
            .font(.title2.monospacedDigit())
            .frame(width: column.isWide ? 48 : 36)
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel(column.accessibilityLabel)
    }
}
#endif

#if os(iOS)
import UIKit

/// A multi-component UIPickerView. Separators are rendered as fixed,
/// single-row components between the numeric columns.
private struct WheelPicker: UIViewRepresentable {
    var columns: [NumberColumn]
    @Binding var values: [Int]

    /// Picker components: numeric columns interleaved with separators.
    private enum Component: Hashable {
        case number(Int)
        case separator(String)
    }

    private var components: [Component] {
        columns.indices.flatMap { i -> [Component] in
            var c: [Component] = [.number(i)]
            if let s = columns[i].separator { c.append(.separator(s)) }
            return c
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        picker.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return picker
    }

    func updateUIView(_ picker: UIPickerView, context: Context) {
        let coordinator = context.coordinator
        let oldColumns = coordinator.parent.columns
        coordinator.parent = self
        if oldColumns != columns {
            picker.reloadAllComponents()
        }
        for (index, component) in components.enumerated() {
            guard case .number(let col) = component else { continue }
            let column = columns[col]
            let offset = values[col] - column.range.lowerBound
            let current = picker.selectedRow(inComponent: index)
            if current % column.range.count != offset || (!column.wraps && current != offset) {
                picker.selectRow(Self.row(for: offset, in: column), inComponent: index, animated: false)
            }
        }
    }

    /// Wrapping columns repeat their values many times; we sit in the middle
    /// copy so the wheel can spin either way.
    static let wrapCopies = 100

    static func rowCount(_ column: NumberColumn) -> Int {
        column.range.count * (column.wraps ? wrapCopies : 1)
    }

    static func row(for offset: Int, in column: NumberColumn) -> Int {
        column.wraps ? (wrapCopies / 2) * column.range.count + offset : offset
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: WheelPicker

        init(_ parent: WheelPicker) { self.parent = parent }

        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            parent.components.count
        }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            switch parent.components[component] {
            case .number(let col): WheelPicker.rowCount(parent.columns[col])
            case .separator: 1
            }
        }

        func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
            switch parent.components[component] {
            case .number(let col): parent.columns[col].isWide ? 64 : 48
            case .separator: 14
            }
        }

        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat { 40 }

        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            let label = (view as? UILabel) ?? UILabel()
            label.font = .monospacedDigitSystemFont(ofSize: 26, weight: .regular)
            label.textAlignment = .center
            switch parent.components[component] {
            case .number(let col):
                let column = parent.columns[col]
                let value = column.range.lowerBound + row % column.range.count
                label.text = column.text(value)
                label.accessibilityLabel = "\(column.text(value)) \(column.accessibilityLabel)"
            case .separator(let s):
                label.text = s
                label.isAccessibilityElement = false
            }
            return label
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            guard case .number(let col) = parent.components[component] else { return }
            let column = parent.columns[col]
            let offset = row % column.range.count
            if column.wraps {
                // Recentre so the wheel never runs out of rows.
                pickerView.selectRow(WheelPicker.row(for: offset, in: column), inComponent: component, animated: false)
            }
            var values = parent.values
            values[col] = column.range.lowerBound + offset
            parent.values = values
        }
    }
}
#endif
