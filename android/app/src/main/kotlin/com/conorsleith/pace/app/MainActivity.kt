package com.conorsleith.pace.app

import android.content.Context
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import com.conorsleith.pace.R
import com.conorsleith.pace.core.DistanceUnit
import com.conorsleith.pace.core.RaceStore
import java.io.File

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val state = AppState(applicationContext)
        setContent {
            PaceTheme {
                PaceApp(state)
            }
        }
    }
}

enum class AppTab { CALCULATOR, RACE }

/**
 * App-wide state. The unit and last tab are kept in preferences; races are
 * written to a JSON file after every change so a race in progress survives
 * the app being closed or killed.
 */
class AppState(context: Context) {
    private val prefs = context.getSharedPreferences("pace", Context.MODE_PRIVATE)
    private val racesFile = File(context.filesDir, "races.json")

    var unit by mutableStateOf(
        runCatching { DistanceUnit.valueOf(prefs.getString("unit", null)!!) }.getOrDefault(DistanceUnit.MI)
    )
        private set

    var tab by mutableStateOf(
        runCatching { AppTab.valueOf(prefs.getString("tab", null)!!) }.getOrDefault(AppTab.CALCULATOR)
    )
        private set

    var races by mutableStateOf(
        runCatching { RaceStore.decoded(racesFile.readText()) }.getOrDefault(RaceStore())
    )
        private set

    fun updateUnit(value: DistanceUnit) {
        unit = value
        prefs.edit().putString("unit", value.name).apply()
    }

    fun updateTab(value: AppTab) {
        tab = value
        prefs.edit().putString("tab", value.name).apply()
    }

    fun updateRaces(value: RaceStore) {
        races = value
        runCatching { racesFile.writeText(value.encoded()) }
    }
}

@Composable
fun PaceApp(state: AppState) {
    Scaffold(
        // Each screen's top bar handles the status bar inset itself.
        contentWindowInsets = WindowInsets(0),
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = state.tab == AppTab.CALCULATOR,
                    onClick = { state.updateTab(AppTab.CALCULATOR) },
                    icon = { Icon(painterResource(R.drawable.ic_timer), contentDescription = null) },
                    label = { Text("Calculator") },
                )
                NavigationBarItem(
                    selected = state.tab == AppTab.RACE,
                    onClick = { state.updateTab(AppTab.RACE) },
                    icon = { Icon(painterResource(R.drawable.ic_flag), contentDescription = null) },
                    label = { Text("Race") },
                )
            }
        },
    ) { padding ->
        val modifier = Modifier.padding(padding)
        when (state.tab) {
            AppTab.CALCULATOR -> CalculatorScreen(state.unit, state::updateUnit, modifier)
            AppTab.RACE -> RaceScreen(state.races, state::updateRaces, state.unit, state::updateUnit, modifier)
        }
    }
}

@Composable
fun PaceTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    val colors = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S ->
            if (dark) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        dark -> darkColorScheme()
        else -> lightColorScheme()
    }
    MaterialTheme(colorScheme = colors, content = content)
}
