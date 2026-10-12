package com.conorsleith.pace.core

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.double
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File
import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** Runs the platform-neutral vectors in PaceCore/Tests/PaceCoreTests/fixtures.json, shared with iOS. */
class FixtureTest {
    private val fixtures: JsonObject =
        Json.parseToJsonElement(File(System.getProperty("fixtures")).readText()).jsonObject

    private fun cases(name: String) = fixtures.getValue(name).jsonArray.map { it.jsonObject }
    private fun JsonObject.d(key: String) = getValue(key).jsonPrimitive.double
    private fun JsonObject.s(key: String) = getValue(key).jsonPrimitive.content

    @Test fun paceToTime() = cases("paceToTime").forEach { f ->
        val time = Pace.per(DistanceUnit.fromLabel(f.s("unit")), f.d("paceSeconds")).timeFor(Distance(f.d("meters")))
        assertEquals(f.s("expected"), TimeFormat.string(time), f.s("name"))
    }

    @Test fun timeToPace() = cases("timeToPace").forEach { f ->
        val pace = Pace.of(f.d("seconds"), Distance(f.d("meters")))
        assertEquals(f.s("expected"), TimeFormat.string(pace.secondsPer(DistanceUnit.fromLabel(f.s("unit")))), f.s("name"))
    }

    @Test fun projection() = cases("projection").forEach { f ->
        val time = Pace.of(f.d("seconds"), Distance(f.d("meters"))).timeFor(Distance(f.d("targetMeters")))
        assertEquals(f.s("expected"), TimeFormat.string(time), f.s("name"))
    }

    @Test fun speed() = cases("speed").forEach { f ->
        val speed = Pace.per(DistanceUnit.fromLabel(f.s("paceUnit")), f.d("paceSeconds"))
            .speedIn(DistanceUnit.fromLabel(f.s("speedUnit")))
        assertTrue(abs(speed - f.d("expected")) < 0.0001, f.s("name"))
    }

    @Test fun splitPoints() = cases("splitPoints").forEach { f ->
        val race = RaceKind.fromId(f.s("race"))
        val type = SplitType.entries.first { it.name.lowercase() == f.s("splitType") }
        val actual = race.splitPoints(type).map { it.meters }
        val expected = f.getValue("meters").jsonArray.map { it.jsonPrimitive.double }
        assertEquals(expected.size, actual.size, "$race")
        actual.zip(expected).forEach { (a, b) -> assertTrue(abs(a - b) < 0.001, "$race $a != $b") }
    }
}
