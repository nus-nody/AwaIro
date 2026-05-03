package io.awairo

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import io.awairo.presentation.component.PaletteSheet
import io.awairo.presentation.screen.GalleryScreen
import io.awairo.presentation.screen.HomeScreen
import io.awairo.presentation.screen.MemoScreen
import io.awairo.presentation.screen.PhotoDetailScreen
import io.awairo.presentation.theme.LocalSkyTheme
import io.awairo.presentation.theme.resolveSkyTheme
import io.awairo.presentation.viewmodel.ThemeViewModel
import org.koin.compose.viewmodel.koinViewModel

sealed class Screen {
    data object Home : Screen()
    data class Memo(val absoluteImagePath: String) : Screen()
    data object Gallery : Screen()
    data class PhotoDetail(val photoId: String) : Screen()
}

@Composable
fun App() {
    val themeVm: ThemeViewModel = koinViewModel()
    val mode by themeVm.themeMode.collectAsState()
    val palette by themeVm.skyPalette.collectAsState()
    val systemDark = isSystemInDarkTheme()
    val skyTheme = remember(mode, palette, systemDark) {
        resolveSkyTheme(palette, mode, systemDark)
    }

    var currentScreen: Screen by remember { mutableStateOf(Screen.Home) }
    var paletteOpen by remember { mutableStateOf(false) }

    CompositionLocalProvider(LocalSkyTheme provides skyTheme) {
        MaterialTheme {
            Surface(modifier = Modifier.fillMaxSize()) {
                Box(modifier = Modifier.fillMaxSize()) {
                    AnimatedContent(
                        targetState = currentScreen,
                        transitionSpec = {
                            (fadeIn() + scaleIn(initialScale = 0.96f))
                                .togetherWith(fadeOut() + scaleOut(targetScale = 1.04f))
                        },
                        label = "screen",
                    ) { screen ->
                        when (screen) {
                            is Screen.Home -> HomeScreen(
                                onPhotoCaptured = { absolutePath -> currentScreen = Screen.Memo(absolutePath) },
                                onOpenGallery = { currentScreen = Screen.Gallery },
                                onOpenMenu = { paletteOpen = !paletteOpen },
                            )
                            is Screen.Memo -> MemoScreen(
                                absoluteImagePath = screen.absoluteImagePath,
                                onSaved = { currentScreen = Screen.Home },
                                onCancel = { currentScreen = Screen.Home },
                            )
                            is Screen.Gallery -> GalleryScreen(
                                onPhotoTap = { id -> currentScreen = Screen.PhotoDetail(id) },
                                onBackToHome = { currentScreen = Screen.Home },
                                onOpenMenu = { paletteOpen = !paletteOpen },
                            )
                            is Screen.PhotoDetail -> PhotoDetailScreen(
                                initialPhotoId = screen.photoId,
                                onBack = { currentScreen = Screen.Gallery },
                                onShareClick = { /* Sprint 3 で実装 */ },
                            )
                        }
                    }

                    // パレットシートは最前面に
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.BottomCenter,
                    ) {
                        PaletteSheet(
                            visible = paletteOpen,
                            currentPalette = palette,
                            currentMode = mode,
                            onPaletteClick = { themeVm.setSkyPalette(it) },
                            onModeClick = { themeVm.setThemeMode(it) },
                        )
                    }
                }
            }
        }
    }
}
