package com.conorsleith.pace.app

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.conorsleith.pace.core.Distance
import com.conorsleith.pace.core.DistanceUnit
import com.conorsleith.pace.core.Pace
import com.conorsleith.pace.core.RaceKind
import com.conorsleith.pace.core.RaceLabel
import com.conorsleith.pace.core.RaceStore
import com.conorsleith.pace.core.SplitAnalysis
import com.conorsleith.pace.core.TimeComponents
import com.conorsleith.pace.core.TimeFormat
import com.conorsleith.pace.core.TrackedRace

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RaceScreen(
    store: RaceStore,
    onStoreChange: (RaceStore) -> Unit,
    unit: DistanceUnit,
    onUnitChange: (DistanceUnit) -> Unit,
    modifier: Modifier = Modifier,
) {
    var isAdding by remember { mutableStateOf(false) }
    var isConfirmingDelete by remember { mutableStateOf(false) }
    var isMenuOpen by remember { mutableStateOf(false) }
    val selected = store.selected

    Column(modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text(selected?.title ?: "Race", maxLines = 1) },
            actions = {
                UnitToggle(unit, onUnitChange)
                Box {
                    IconButton(onClick = { isMenuOpen = true }) {
                        Icon(Icons.Filled.MoreVert, contentDescription = "Races")
                    }
                    DropdownMenu(expanded = isMenuOpen, onDismissRequest = { isMenuOpen = false }) {
                        DropdownMenuItem(text = { Text("Add race") }, onClick = { isMenuOpen = false; isAdding = true })
                        if (selected != null) {
                            DropdownMenuItem(
                                text = { Text("Delete this race", color = MaterialTheme.colorScheme.error) },
                                onClick = { isMenuOpen = false; isConfirmingDelete = true },
                            )
                        }
                    }
                }
            },
        )

        if (store.races.size > 1) {
            RacePicker(store) { onStoreChange(store.copy(selectedId = it)) }
        }

        if (selected == null) {
            Column(
                Modifier.fillMaxSize().padding(32.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("No races", style = MaterialTheme.typography.headlineSmall)
                Text(
                    "Add a race to follow it split by split.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
                Spacer(Modifier.height(16.dp))
                Button(onClick = { isAdding = true }) { Text("Add race") }
            }
        } else {
            RaceDetail(selected, unit) { onStoreChange(store.update(it)) }
        }
    }

    if (isAdding) {
        AddRaceSheet(onDismiss = { isAdding = false }) {
            onStoreChange(store.add(it))
            isAdding = false
        }
    }

    if (isConfirmingDelete && selected != null) {
        AlertDialog(
            onDismissRequest = { isConfirmingDelete = false },
            title = { Text("Delete ${selected.title}?") },
            text = { Text("Its recorded splits will be lost.") },
            confirmButton = {
                TextButton(onClick = {
                    onStoreChange(store.remove(selected.id))
                    isConfirmingDelete = false
                }) { Text("Delete", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { isConfirmingDelete = false }) { Text("Cancel") } },
        )
    }
}

/** Segmented control for 2–3 races, scrolling chips beyond that. */
@Composable
private fun RacePicker(store: RaceStore, onSelect: (String) -> Unit) {
    val selectedId = store.selected?.id
    // When all races share a kind (e.g. men's and women's marathon) the
    // label alone is enough to tell them apart.
    val sameKind = store.races.map { it.kind }.distinct().size == 1
    fun shortTitle(race: TrackedRace) =
        if (sameKind && race.customName.isNullOrEmpty() && race.label != RaceLabel.NONE) race.label.label else race.title

    if (store.races.size <= 3) {
        SegmentedChoice(
            options = store.races.map { it.id },
            selected = selectedId,
            label = { id -> shortTitle(store.races.first { it.id == id }) },
            onSelect = { onSelect(it!!) },
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
        )
    } else {
        Row(
            Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            store.races.forEach { race ->
                FilterChip(selected = race.id == selectedId, onClick = { onSelect(race.id) }, label = { Text(race.title) })
            }
        }
    }
}

/** Projections, split entry and the split list for one race. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun RaceDetail(race: TrackedRace, unit: DistanceUnit, onChange: (TrackedRace) -> Unit) {
    // Prefill the wheels whenever the selected split point changes. Rounded to
    // what the wheels can show, so a recorded split is exactly the time on screen.
    var entry by remember(race.id, race.selectedPointIndex) {
        mutableDoubleStateOf(TimeComponents.roundToTenths(race.projectedElapsed(race.selectedPointIndex)))
    }
    val index = race.selectedPointIndex
    val point = race.points[index]
    val existing = race.splitAt(index)
    val canRecord = race.canRecord(entry, index)
    val analysis = race.analysis.associateBy { it.pointIndex }

    // Track races show lap pace per 400m; road races show pace per mi/km.
    fun paceText(pace: Pace) =
        if (race.kind.isTrack) "${TimeFormat.string(pace.timeFor(Distance(400.0)))} /400"
        else "${TimeFormat.string(pace.secondsPer(unit))} ${unit.paceSuffix}"

    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Card(shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("Projected finish", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    when {
                        race.splits.isEmpty() ->
                            Text("Record the first split to see a projection.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                        race.isFinished ->
                            ProjectionRow("Finished", race.splits.last().elapsed, null)
                        else -> {
                            ProjectionRow("At average pace", race.projectedFinishAtAverage, race.averagePace?.let(::paceText))
                            if (race.splits.size > 1) {
                                ProjectionRow("At last-segment pace", race.projectedFinishAtLastSegment, race.lastSegmentPace?.let(::paceText))
                            }
                        }
                    }
                }
            }
        }

        item {
            Card(shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        IconButton(onClick = { onChange(race.select(index - 1)) }, enabled = index > 0) {
                            Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, contentDescription = "Previous split point")
                        }
                        Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(point.label, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                            Text(
                                "split ${index + 1} of ${race.points.size}",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        IconButton(onClick = { onChange(race.select(index + 1)) }, enabled = index < race.points.size - 1) {
                            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = "Next split point")
                        }
                    }

                    DurationInput(entry, showsHours = !race.kind.isTrack) { entry = it }

                    if (!canRecord) {
                        val range = race.allowedRange(index)
                        val hint = when {
                            range.before != null && entry >= range.before!! -> "Must be before ${TimeFormat.string(range.before!!)}"
                            range.after > 0 -> "Must be after ${TimeFormat.string(range.after)}"
                            else -> "Enter a time"
                        }
                        Text(hint, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                    }

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Button(onClick = { race.record(entry, index)?.let(onChange) }, enabled = canRecord) {
                            Text(if (existing == null) "Record ${point.label}" else "Update ${point.label}")
                        }
                        Spacer(Modifier.weight(1f))
                        if (existing != null) {
                            OutlinedButton(onClick = { onChange(race.removeSplit(index)) }) {
                                Text("Clear", color = MaterialTheme.colorScheme.error)
                            }
                        } else if (race.splits.isNotEmpty()) {
                            OutlinedButton(onClick = { onChange(race.undoLast()) }) { Text("Undo last") }
                        }
                    }
                }
            }
        }

        item { Text("Splits", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }

        items(race.points.indices.toList(), key = { it }) { i ->
            val isSelected = i == index
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(if (isSelected) MaterialTheme.colorScheme.primaryContainer else Color.Transparent)
                    .combinedClickable(
                        onClick = { onChange(race.select(i)) },
                        // Long-press clears a recorded split.
                        onLongClick = { if (analysis[i] != null) onChange(race.removeSplit(i)) },
                    )
                    .padding(horizontal = 12.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    race.points[i].label,
                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                    modifier = Modifier.weight(1f),
                )
                SplitValue(analysis[i], race.projectedElapsed(i), showsProjection = race.splits.isNotEmpty(), paceText = ::paceText)
            }
        }
    }
}

@Composable
private fun ProjectionRow(title: String, time: Double?, pace: String?) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(title, color = MaterialTheme.colorScheme.onSurfaceVariant)
            pace?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
        Text(timeText(time), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun SplitValue(analysis: SplitAnalysis?, projected: Double, showsProjection: Boolean, paceText: (Pace) -> String) {
    when {
        analysis != null -> Column(horizontalAlignment = Alignment.End) {
            Text(TimeFormat.string(analysis.elapsed), fontWeight = FontWeight.SemiBold)
            Text(
                "${TimeFormat.string(analysis.segmentTime)} · ${paceText(analysis.segmentPace)}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        showsProjection -> Text(
            TimeFormat.string(projected),
            fontStyle = FontStyle.Italic,
            color = MaterialTheme.colorScheme.outline,
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AddRaceSheet(onDismiss: () -> Unit, onAdd: (TrackedRace) -> Unit) {
    var kind by remember { mutableStateOf(RaceKind.MARATHON) }
    var splitType by remember { mutableStateOf(kind.defaultSplitType) }
    var label by remember { mutableStateOf(RaceLabel.NONE) }
    var name by remember { mutableStateOf("") }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
        Column(Modifier.padding(horizontal = 16.dp).padding(bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = onDismiss) { Text("Cancel") }
                Text("Add race", style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
                TextButton(onClick = {
                    onAdd(TrackedRace(kind = kind, splitType = splitType, label = label, customName = name.trim().ifEmpty { null }))
                }) { Text("Add", fontWeight = FontWeight.SemiBold) }
            }

            Text("Track", style = MaterialTheme.typography.titleSmall)
            ChipGrid(RaceKind.entries.filter { it.isTrack }, 3, { it == kind }, { it.label }) {
                kind = it
                splitType = it.defaultSplitType
            }
            Text("Road", style = MaterialTheme.typography.titleSmall)
            ChipGrid(RaceKind.entries.filter { !it.isTrack }, 3, { it == kind }, { it.label }) {
                kind = it
                splitType = it.defaultSplitType
            }

            if (kind.splitTypes.size > 1) {
                Text("Splits", style = MaterialTheme.typography.titleSmall)
                SegmentedChoice(kind.splitTypes, splitType, { it.label }, { splitType = it }, Modifier.fillMaxWidth())
            }

            Text("Label", style = MaterialTheme.typography.titleSmall)
            ChipGrid(RaceLabel.entries, 3, { it == label }, { it.label }) { label = it }
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("Custom name (optional)") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Done),
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}
