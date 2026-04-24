package io.awairo

import androidx.compose.ui.window.ComposeUIViewController
import io.awairo.di.initKoinForIos

fun MainViewController() = ComposeUIViewController(
    configure = { initKoinForIos() }
) {
    App()
}
