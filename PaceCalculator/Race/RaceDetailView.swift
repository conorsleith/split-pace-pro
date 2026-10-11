import PaceCore
import SwiftUI

/// Projections, split entry and the split list for one race.
struct RaceDetailView: View {
    @Binding var race: TrackedRace
    var unit: DistanceUnit
    @Environment(\.isWideLayout) private var isWide

    /// Time on the wheels for the selected split point.
    @State private var entry: Double = 0

    var body: some View {
        Group {
            if isWide {
                HStack(spacing: 0) {
                    Form {
                        projectionSection
                        entrySection
                    }
                    .frame(minWidth: 340, idealWidth: 400, maxWidth: 460)
                    Divider()
                    List { splitsSection }
                }
            } else {
                Form {
                    projectionSection
                    entrySection
                    splitsSection
                }
            }
        }
        // Prefill the wheels whenever the selected split point changes.
        .task(id: race.selectedPointIndex) {
            // Round to what the wheels can show, so a recorded split is
            // exactly the time on screen.
            let projected = race.projectedElapsed(at: race.selectedPointIndex)
            entry = TimeComponents(totalSeconds: projected).totalSeconds
        }
    }

    // MARK: Projection

    private var projectionSection: some View {
        Section("Projected finish") {
            if race.splits.isEmpty {
                Text("Record the first split to see a projection.")
                    .foregroundStyle(.secondary)
            } else if race.isFinished {
                LabeledContent("Finished", value: timeText(race.splits.last?.elapsed))
                    .font(.title2.monospacedDigit())
            } else {
                ProjectionRow(
                    title: "At average pace",
                    time: race.projectedFinishAtAverage,
                    pace: race.averagePace.map(paceText)
                )
                if race.splits.count > 1 {
                    ProjectionRow(
                        title: "At last-segment pace",
                        time: race.projectedFinishAtLastSegment,
                        pace: race.lastSegmentPace.map(paceText)
                    )
                }
            }
        }
    }

    // MARK: Entry

    private var selectedPoint: SplitPoint { race.points[race.selectedPointIndex] }
    private var existingSplit: RecordedSplit? { race.split(at: race.selectedPointIndex) }
    private var canRecord: Bool { race.canRecord(entry, at: race.selectedPointIndex) }

    private var entrySection: some View {
        Section {
            HStack {
                Button {
                    race.selectedPointIndex -= 1
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(race.selectedPointIndex == 0)
                .accessibilityLabel("Previous split point")

                Spacer()
                VStack(spacing: 2) {
                    Text(selectedPoint.label).font(.title2.weight(.semibold))
                    Text("split \(race.selectedPointIndex + 1) of \(race.points.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Button {
                    race.selectedPointIndex += 1
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(race.selectedPointIndex == race.points.count - 1)
                .accessibilityLabel("Next split point")
            }
            .buttonStyle(.borderless)
            .font(.title3)

            DurationInput(seconds: $entry, showsHours: !race.kind.isTrack)

            if !canRecord {
                Text(orderHint).font(.footnote).foregroundStyle(.red)
            }

            HStack {
                Button(existingSplit == nil ? "Record \(selectedPoint.label)" : "Update \(selectedPoint.label)") {
                    race.record(entry, at: race.selectedPointIndex)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canRecord)

                Spacer()

                if existingSplit != nil {
                    Button("Clear", role: .destructive) {
                        race.removeSplit(at: race.selectedPointIndex)
                    }
                    .buttonStyle(.bordered)
                } else if !race.splits.isEmpty {
                    Button("Undo last") { race.undoLast() }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private var orderHint: String {
        let range = race.allowedRange(at: race.selectedPointIndex)
        if let before = range.before, entry >= before {
            return "Must be before \(TimeFormat.string(before))"
        }
        return range.after > 0 ? "Must be after \(TimeFormat.string(range.after))" : "Enter a time"
    }

    // MARK: Splits

    private var splitsSection: some View {
        let analysis = Dictionary(uniqueKeysWithValues: race.analysis.map { ($0.pointIndex, $0) })
        return Section("Splits") {
            ForEach(race.points.indices, id: \.self) { i in
                SplitRow(
                    point: race.points[i],
                    analysis: analysis[i],
                    projected: race.projectedElapsed(at: i),
                    showsProjection: !race.splits.isEmpty,
                    paceText: paceText,
                    isSelected: i == race.selectedPointIndex
                )
                .contentShape(Rectangle())
                .onTapGesture { race.selectedPointIndex = i }
                .listRowBackground(i == race.selectedPointIndex ? Color.accentColor.opacity(0.15) : nil)
                .swipeActions {
                    if analysis[i] != nil {
                        Button("Clear", role: .destructive) { race.removeSplit(at: i) }
                    }
                }
            }
        }
    }

    /// Track races show lap pace per 400m; road races show pace per mi/km.
    private func paceText(_ pace: Pace) -> String {
        if race.kind.isTrack {
            return "\(TimeFormat.string(pace.time(for: Distance(meters: 400)))) /400"
        }
        return "\(TimeFormat.string(pace.seconds(per: unit))) \(unit.paceSuffix)"
    }
}

private struct ProjectionRow: View {
    var title: String
    var time: Double?
    var pace: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                if let pace {
                    Text(pace).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(timeText(time))
                .font(.title.weight(.semibold).monospacedDigit())
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SplitRow: View {
    var point: SplitPoint
    var analysis: SplitAnalysis?
    var projected: Double
    var showsProjection: Bool
    var paceText: (Pace) -> String
    var isSelected: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(point.label)
                .fontWeight(isSelected ? .semibold : .regular)
                .frame(minWidth: 64, alignment: .leading)
            Spacer()
            if let analysis {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(TimeFormat.string(analysis.elapsed))
                        .fontWeight(.semibold)
                    Text("\(TimeFormat.string(analysis.segmentTime)) · \(paceText(analysis.segmentPace))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .monospacedDigit()
            } else if showsProjection {
                Text(TimeFormat.string(projected))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
        .accessibilityElement(children: .combine)
    }
}
