package io.awairo.domain.repository

import io.awairo.domain.model.SkyPalette
import io.awairo.domain.model.ThemeMode
import kotlinx.coroutines.flow.StateFlow

interface ThemeRepository {
    fun observeThemeMode(): StateFlow<ThemeMode>
    suspend fun setThemeMode(mode: ThemeMode)
    fun observeSkyPalette(): StateFlow<SkyPalette>
    suspend fun setSkyPalette(palette: SkyPalette)
}
