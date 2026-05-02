package io.awairo.domain.repository

import io.awairo.domain.model.SkyPalette
import io.awairo.domain.model.ThemeMode
import kotlinx.coroutines.flow.StateFlow

interface ThemeRepository {
    fun observeThemeMode(): StateFlow<ThemeMode>
    fun setThemeMode(mode: ThemeMode)
    fun observeSkyPalette(): StateFlow<SkyPalette>
    fun setSkyPalette(palette: SkyPalette)
}
