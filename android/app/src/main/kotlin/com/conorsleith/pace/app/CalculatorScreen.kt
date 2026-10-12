package com.conorsleith.pace.app

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.conorsleith.pace.core.Calculation
import com.conorsleith.pace.core.Distance
import com.conorsleith.pace.core.DistanceUnit
import com.conorsleith.pace.core.Pace
import com.conorsleith.pace.core.PresetDistance
import com.conorsleith.pace.core.TimeFormat

/** The row being edited. */
enum class CalculatorField(val title: String) { DISTANCE("Distance"), TIME("Time"), PACE("Pace") }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CalculatorScreen(
    unit: DistanceUnit,
    onUnitChange: (DistanceUnit) -> Unit,
    customUnit: DistanceUnit,
    onCustomUnitChange: (DistanceUnit) -> Unit,
    modifier: Modifier = Modifier,
) {
    var calc by remember { mutableStateOf(Calculation(PresetDistance.K5.distance, 20 * 60.0)) }
    var editing by rememberSaveable { mutableStateOf<CalculatorField?>(null) }
    var isCustomDistance by rememberSaveable { mutableStateOf(false) }

    BackHandler(enabled = editing != null) { editing = null }

    Column(modifier.fillMaxSize()) {
        CenterAlignedTopAppBar(title = { UnitToggle(unit, onUnitChange) })

        LazyColumn(Modifier.weight(1f), contentPadding = PaddingValues(horizontal = 16.dp)) {
            item {
                Card(shape = RoundedCornerShape(16.dp)) {
                    FieldRow(
                        title = "Distance",
                        value = distanceText(calc.distance, customUnit),
                        isEditing = editing == CalculatorField.DISTANCE,
                        isCalculated = false,
                    ) { editing = toggle(editing, CalculatorField.DISTANCE) }
                    HorizontalDivider()
                    FieldRow(
                        title = "Time",
                        value = timeText(calc.time),
                        isEditing = editing == CalculatorField.TIME,
                        isCalculated = calc.calculated == Calculation.Field.TIME,
                    ) { editing = toggle(editing, CalculatorField.TIME) }
                    HorizontalDivider()
                    FieldRow(
                        title = "Pace",
                        value = paceText(calc.pace, unit),
                        suffix = unit.paceSuffix,
                        detail = "${paceText(calc.pace, unit.other)} ${unit.other.paceSuffix} · ${speedText(calc.pace, unit)}",
                        isEditing = editing == CalculatorField.PACE,
                        isCalculated = calc.calculated == Calculation.Field.PACE,
                    ) { editing = toggle(editing, CalculatorField.PACE) }
                }
            }
            // The input for the row being edited, directly under the rows:
            // mid-screen where the thumb rests, away from the bottom edge.
            editing?.let { field ->
                item(key = "editor") {
                    EditorCard(field.title, onDone = { editing = null }) {
                        when (field) {
                            CalculatorField.DISTANCE -> DistancePicker(calc.distance, isCustomDistance, customUnit, onCustomUnitChange,
                                onCustomChange = { isCustomDistance = it },
                                onChange = { calc = calc.withDistance(it) })
                            CalculatorField.TIME -> DurationInput(calc.time) { calc = calc.withTime(it) }
                            CalculatorField.PACE -> DurationInput(calc.pace.secondsPer(unit), showsHours = false) {
                                calc = calc.withPace(Pace.per(unit, it))
                            }
                        }
                    }
                }
            }
            item { SectionHeader("Splits") }
            items(splitRows(calc.distance), key = { it.distance.meters }) { row ->
                SplitTableRow(row, calc.pace) {
                    // Tapping a split makes it the distance, keeping the current pace.
                    if (calc.pace.isValid) {
                        calc = calc.withDistanceKeepingPace(row.distance)
                        isCustomDistance = PresetDistance.of(row.distance) == null
                    }
                }
            }
            item { Spacer(Modifier.padding(bottom = 16.dp)) }
        }
    }
}

private fun toggle(current: CalculatorField?, field: CalculatorField) = if (current == field) null else field

private fun distanceText(distance: Distance, unit: DistanceUnit): String =
    PresetDistance.of(distance)?.label ?: "%.2f %s".format(distance.valueIn(unit), unit.label)

fun timeText(seconds: Double?): String =
    if (seconds == null || !seconds.isFinite() || seconds <= 0) "—" else TimeFormat.string(seconds)

private fun paceText(pace: Pace, unit: DistanceUnit) = if (pace.isValid) TimeFormat.string(pace.secondsPer(unit)) else "—"

private fun speedText(pace: Pace, unit: DistanceUnit) =
    if (pace.isValid) "%.1f %s".format(pace.speedIn(unit), unit.speedLabel) else "— ${unit.speedLabel}"

/**
 * A tappable label/value row. The calculated value is shown in the accent
 * colour so it's always clear which number is the answer.
 */
@Composable
private fun FieldRow(
    title: String,
    value: String,
    isEditing: Boolean,
    isCalculated: Boolean,
    suffix: String? = null,
    detail: String? = null,
    onClick: () -> Unit,
) {
    val colors = MaterialTheme.colorScheme
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(if (isEditing) colors.primaryContainer else Color.Transparent)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, color = colors.onSurfaceVariant)
            if (isCalculated) {
                Text("calculated", style = MaterialTheme.typography.labelSmall, color = colors.primary)
            }
        }
        Column(horizontalAlignment = Alignment.End) {
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    value,
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = if (isCalculated) colors.primary else colors.onSurface,
                )
                suffix?.let {
                    Spacer(Modifier.width(4.dp))
                    Text(it, color = colors.onSurfaceVariant, modifier = Modifier.padding(bottom = 4.dp))
                }
            }
            detail?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = colors.onSurfaceVariant) }
        }
    }
}

private data class SplitRow(val name: String, val distance: Distance, val isHighlighted: Boolean)

/** Every preset distance, plus the current distance if it's custom. */
private fun splitRows(current: Distance): List<SplitRow> {
    val rows = PresetDistance.entries.map {
        SplitRow(it.label, it.distance, kotlin.math.abs(it.meters - current.meters) < 0.001)
    }.toMutableList()
    if (current.meters > 0 && PresetDistance.of(current) == null) {
        val name = "%.2f km · %.2f mi".format(current.valueIn(DistanceUnit.KM), current.valueIn(DistanceUnit.MI))
        rows += SplitRow(name, current, true)
        rows.sortBy { it.distance.meters }
    }
    return rows
}

@Composable
private fun SplitTableRow(row: SplitRow, pace: Pace, onClick: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(if (row.isHighlighted) colors.primaryContainer else Color.Transparent)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        val weight = if (row.isHighlighted) FontWeight.SemiBold else FontWeight.Normal
        Text(row.name, fontWeight = weight, modifier = Modifier.weight(1f))
        Text(if (pace.isValid) TimeFormat.string(pace.timeFor(row.distance)) else "—", fontWeight = weight)
    }
}

/** Preset distance buttons; "Custom" adds whole + hundredths wheels below them. */
@Composable
private fun DistancePicker(
    distance: Distance,
    isCustom: Boolean,
    unit: DistanceUnit,
    onUnitChange: (DistanceUnit) -> Unit,
    onCustomChange: (Boolean) -> Unit,
    onChange: (Distance) -> Unit,
) {
    val options: List<PresetDistance?> = PresetDistance.entries + null
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        ChipGrid(
            options = options,
            columns = 5,
            isSelected = { if (it == null) isCustom else !isCustom && PresetDistance.of(distance) == it },
            label = { it?.label ?: "Custom" },
        ) { preset ->
            if (preset == null) {
                onCustomChange(true)
            } else {
                onCustomChange(false)
                onChange(preset.distance)
            }
        }
        if (isCustom) {
            DecimalDistanceInput(distance, unit, onUnitChange, onChange)
        }
    }
}

/** Card holding the input for the row being edited. */
@Composable
private fun EditorCard(title: String, onDone: () -> Unit, content: @Composable () -> Unit) {
    // Lighter than the rows card, so the distance buttons stand out against it.
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
        modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
    ) {
        Column(Modifier.padding(start = 16.dp, end = 8.dp, top = 4.dp, bottom = 12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                TextButton(onClick = onDone) { Text("Done", fontWeight = FontWeight.SemiBold) }
            }
            Column(Modifier.padding(end = 8.dp)) { content() }
        }
    }
}
