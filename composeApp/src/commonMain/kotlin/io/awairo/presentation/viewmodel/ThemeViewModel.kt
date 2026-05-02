package io.awairo.presentation.viewmodel

import androidx.lifecycle.ViewModel
import io.awairo.domain.model.SkyPalette
import io.awairo.domain.model.ThemeMode
import io.awairo.domain.repository.ThemeRepository
import kotlinx.coroutines.flow.StateFlow

class ThemeViewModel(
    private val repository: ThemeRepository
) : ViewModel() {

    val themeMode: StateFlow<ThemeMode> = repository.observeThemeMode()
    val skyPalette: StateFlow<SkyPalette> = repository.observeSkyPalette()

    fun setThemeMode(mode: ThemeMode) {
        repository.setThemeMode(mode)
    }

    fun setSkyPalette(palette: SkyPalette) {
        repository.setSkyPalette(palette)
    }
}
