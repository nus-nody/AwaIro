package io.awairo

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import io.awairo.presentation.screen.HomeScreen
import io.awairo.presentation.screen.MemoScreen

sealed class Screen {
    object Home : Screen()
    data class Memo(val absoluteImagePath: String) : Screen()
}

@Composable
fun App() {
    var currentScreen: Screen by remember { mutableStateOf(Screen.Home) }

    MaterialTheme {
        Surface {
            when (val screen = currentScreen) {
                is Screen.Home -> HomeScreen(
                    onPhotoCaptured = { absolutePath ->
                        currentScreen = Screen.Memo(absolutePath)
                    }
                )
                is Screen.Memo -> MemoScreen(
                    absoluteImagePath = screen.absoluteImagePath,
                    onSaved = { currentScreen = Screen.Home },
                    onCancel = { currentScreen = Screen.Home }
                )
            }
        }
    }
}
