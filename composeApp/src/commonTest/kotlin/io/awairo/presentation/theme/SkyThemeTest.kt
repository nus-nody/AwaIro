package io.awairo.presentation.theme

import io.awairo.domain.model.SkyPalette
import io.awairo.domain.model.ThemeMode
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class SkyThemeTest {

    @Test
    fun resolveSkyTheme_systemMode_followsSystemDarkFlag_true() {
        val theme = resolveSkyTheme(SkyPalette.NIGHT_SKY, ThemeMode.SYSTEM, isSystemDark = true)
        assertTrue(theme.isDark)
    }

    @Test
    fun resolveSkyTheme_systemMode_followsSystemDarkFlag_false() {
        val theme = resolveSkyTheme(SkyPalette.NIGHT_SKY, ThemeMode.SYSTEM, isSystemDark = false)
        assertFalse(theme.isDark)
    }

    @Test
    fun resolveSkyTheme_darkMode_isDark_regardlessOfSystem() {
        val theme = resolveSkyTheme(SkyPalette.MIST, ThemeMode.DARK, isSystemDark = false)
        assertTrue(theme.isDark)
    }

    @Test
    fun resolveSkyTheme_lightMode_isLight_regardlessOfSystem() {
        val theme = resolveSkyTheme(SkyPalette.DUSK, ThemeMode.LIGHT, isSystemDark = true)
        assertFalse(theme.isDark)
    }

    @Test
    fun resolveSkyTheme_carriesPaletteAndMode() {
        val theme = resolveSkyTheme(SkyPalette.KOMOREBI, ThemeMode.DARK, isSystemDark = false)
        assertEquals(SkyPalette.KOMOREBI, theme.palette)
        assertEquals(ThemeMode.DARK, theme.mode)
    }
}
