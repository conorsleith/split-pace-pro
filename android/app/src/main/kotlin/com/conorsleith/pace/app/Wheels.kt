package com.conorsleith.pace.app

import android.os.Build
import android.util.TypedValue
import android.widget.NumberPicker
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.conorsleith.pace.core.Distance
import com.conorsleith.pace.core.DistanceUnit
import com.conorsleith.pace.core.TimeComponents

/** One numeric column of a multi-column input, e.g. minutes 0..59. */
data class NumberColumn(
    val range: IntRange,
    /** Zero-pad to this many digits. */
    val digits: Int = 1,
    /** Fixed text shown after the column, e.g. ":" or ".". */
    val separator: String? = null,
    /** Wheel wraps around (59 → 00), like a timer. */
    val wraps: Boolean = false,
    /** Text shown for each value instead of the number, e.g. ["mi", "km"]. */
    val labels: List<String>? = null,
    val description: String,
) {
    /** Wider column for two-digit numbers and text labels. */
    val isWide: Boolean get() = digits > 1 || labels != null

    fun text(value: Int) = labels?.get(value - range.first) ?: value.toString().padStart(digits, '0')
}

/** A row of spinner wheels with fixed separators between them. */
@Composable
fun NumberColumnsInput(columns: List<NumberColumn>, values: List<Int>, onChange: (List<Int>) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        columns.forEachIndexed { i, column ->
            Wheel(column, values[i]) { newValue ->
                onChange(values.toMutableList().also { it[i] = newValue })
            }
            column.separator?.let {
                Text(it, style = MaterialTheme.typography.headlineSmall, modifier = Modifier.padding(horizontal = 2.dp))
            }
        }
    }
}

/** Android's built-in spinner wheel, wrapped for Compose. */
@Composable
private fun Wheel(column: NumberColumn, value: Int, onValueChange: (Int) -> Unit) {
    AndroidView(
        modifier = Modifier.width(if (column.isWide) 64.dp else 52.dp),
        factory = { context ->
            NumberPicker(context).apply {
                // Spin only; never pop up a keyboard.
                descendantFocusability = NumberPicker.FOCUS_BLOCK_DESCENDANTS
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, 24f, resources.displayMetrics)
                }
            }
        },
        update = { picker ->
            val labels = column.range.map(column::text).toTypedArray()
            if (picker.displayedValues?.toList() != labels.toList()) {
                // Clear labels before changing the range, or NumberPicker throws.
                picker.displayedValues = null
                picker.minValue = 0
                picker.maxValue = labels.size - 1
                picker.displayedValues = labels
            }
            picker.wrapSelectorWheel = column.wraps
            picker.contentDescription = column.description
            picker.setOnValueChangedListener(null)
            val index = (value - column.range.first).coerceIn(0, labels.size - 1)
            if (picker.value != index) picker.value = index
            picker.setOnValueChangedListener { _, _, new -> onValueChange(column.range.first + new) }
        },
    )
}

/** Time entry as h : mm : ss . t (hours optional). */
@Composable
fun DurationInput(seconds: Double, showsHours: Boolean = true, onChange: (Double) -> Unit) {
    val columns = buildList {
        if (showsHours) add(NumberColumn(0..23, separator = ":", description = "hours"))
        add(NumberColumn(0..59, digits = if (showsHours) 2 else 1, separator = ":", wraps = true, description = "minutes"))
        add(NumberColumn(0..59, digits = 2, separator = ".", wraps = true, description = "seconds"))
        add(NumberColumn(0..9, wraps = true, description = "tenths"))
    }
    val t = TimeComponents.of(seconds)
    val minutes = if (showsHours) t.minutes else minOf(59, t.hours * 60 + t.minutes)
    val values = (if (showsHours) listOf(t.hours) else emptyList()) + listOf(minutes, t.seconds, t.tenths)
    NumberColumnsInput(columns, values) { v ->
        val o = if (showsHours) 1 else 0
        onChange(TimeComponents(if (showsHours) v[0] else 0, v[o], v[o + 1], v[o + 2]).totalSeconds)
    }
}

/**
 * Distance entry as whole . hundredths, with a third mi / km wheel.
 * Spinning the unit wheel converts the numbers shown; the distance itself
 * only changes when a number wheel is spun.
 */
@Composable
fun DecimalDistanceInput(
    distance: Distance,
    unit: DistanceUnit,
    onUnitChange: (DistanceUnit) -> Unit,
    onChange: (Distance) -> Unit,
) {
    val units = listOf(DistanceUnit.MI, DistanceUnit.KM)
    val hundredths = Math.round(distance.valueIn(unit) * 100).toInt()
    NumberColumnsInput(
        columns = listOf(
            NumberColumn(0..200, separator = ".", description = if (unit == DistanceUnit.MI) "miles" else "kilometers"),
            NumberColumn(0..99, digits = 2, wraps = true, separator = " ", description = "hundredths"),
            NumberColumn(0..1, labels = units.map { it.label }, description = "unit"),
        ),
        values = listOf(minOf(200, hundredths / 100), hundredths % 100, units.indexOf(unit)),
    ) { v ->
        val newUnit = units[v[2]]
        if (newUnit != unit) onUnitChange(newUnit) else onChange(Distance(v[0] + v[1] / 100.0, unit))
    }
}
