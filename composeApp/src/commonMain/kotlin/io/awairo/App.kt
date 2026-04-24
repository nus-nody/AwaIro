package io.awairo

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import io.awairo.presentation.screen.HomeScreen

@Composable
fun App() {
    MaterialTheme {
        Surface {
            HomeScreen()
        }
    }
}
