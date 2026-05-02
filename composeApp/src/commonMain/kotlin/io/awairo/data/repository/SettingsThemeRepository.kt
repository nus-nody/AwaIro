package io.awairo.data.repository

import com.russhwolf.settings.Settings
import io.awairo.domain.model.SkyPalette
import io.awairo.domain.model.ThemeMode
import io.awairo.domain.repository.ThemeRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class SettingsThemeRepository(
    private val settings: Settings
) : ThemeRepository {

    private val mode = MutableStateFlow(loadMode())
    private val palette = MutableStateFlow(loadPalette())

    override fun observeThemeMode(): StateFlow<ThemeMode> = mode.asStateFlow()

    override suspend fun setThemeMode(mode: ThemeMode) {
        settings.putString(KEY_MODE, mode.name)
        this.mode.value = mode
    }

    override fun observeSkyPalette(): StateFlow<SkyPalette> = palette.asStateFlow()

    override suspend fun setSkyPalette(palette: SkyPalette) {
        settings.putString(KEY_PALETTE, palette.name)
        this.palette.value = palette
    }

    private fun loadMode(): ThemeMode = settings.getStringOrNull(KEY_MODE)
        ?.let { runCatching { ThemeMode.valueOf(it) }.getOrNull() }
        ?: ThemeMode.SYSTEM

    private fun loadPalette(): SkyPalette = settings.getStringOrNull(KEY_PALETTE)
        ?.let { runCatching { SkyPalette.valueOf(it) }.getOrNull() }
        ?: SkyPalette.NIGHT_SKY

    companion object {
        private const val KEY_MODE = "theme_mode"
        private const val KEY_PALETTE = "sky_palette"
    }
}
