import PaceCore
import SwiftUI

/// Preset distance chips plus a custom distance wheel.
struct DistancePicker: View {
    @Binding var distance: Distance
    @Binding var isCustom: Bool
    var unit: DistanceUnit

    private let grid = [GridItem(.adaptive(minimum: 58), spacing: 6)]

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: grid, spacing: 8) {
                ForEach(PresetDistance.allCases) { preset in
                    Chip(title: preset.name, isSelected: !isCustom && PresetDistance(distance: distance) == preset) {
                        isCustom = false
                        distance = preset.distance
                    }
                }
                Chip(title: "Custom", isSelected: isCustom) {
                    isCustom = true
                }
            }
            if isCustom {
                DecimalDistanceInput(distance: $distance, unit: unit)
            }
        }
        .padding(.vertical, 4)
    }
}

struct Chip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
