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

    override fun setThemeMode(mode: ThemeMode) {
        // 先に in-memory を更新して UI を即座に反映、その後に永続化。
        // 永続化が失敗しても画面表示はユーザー操作と一致する。
        this.mode.value = mode
        settings.putString(KEY_MODE, mode.name)
    }

    override fun observeSkyPalette(): StateFlow<SkyPalette> = palette.asStateFlow()

    override fun setSkyPalette(palette: SkyPalette) {
        this.palette.value = palette
        settings.putString(KEY_PALETTE, palette.name)
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
